// BikeLanes/Views/Report/CameraPicker.swift
import SwiftUI
import UIKit
import ImageIO
import CoreLocation
import UniformTypeIdentifiers

/// SwiftUI wrapper around `UIImagePickerController` with `sourceType = .camera`.
/// PhotosPicker covers the library case, but there is no SwiftUI-native camera
/// control yet — so we bridge to UIKit for the capture path.
///
/// `UIImagePickerController` returns a bare `UIImage` and `img.jpegData(...)`
/// drops all metadata, so in-app camera photos used to have no GPS — breaking
/// the EXIF-driven address auto-fill. We run a `CLLocationManager` while the
/// camera is open and stamp the current coordinate + heading into the saved
/// JPEG's GPS block, so `ExifService` resolves an address just like a library
/// photo. Location is best-effort: no fix (or denied permission) simply falls
/// back to the old no-GPS behavior and the user enters the address manually.
struct CameraPicker: UIViewControllerRepresentable {
    let onCaptured: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        context.coordinator.startLocating()
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCaptured: onCaptured, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate, CLLocationManagerDelegate {
        let onCaptured: (URL) -> Void
        let dismiss: () -> Void
        private let locationManager = CLLocationManager()

        init(onCaptured: @escaping (URL) -> Void, dismiss: @escaping () -> Void) {
            self.onCaptured = onCaptured
            self.dismiss = dismiss
            super.init()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }

        /// Begin acquiring a fix as soon as the camera opens so one is ready by
        /// the time the user captures.
        func startLocating() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                locationManager.startUpdatingHeading()
            }
        }

        private func stopLocating() {
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
        }

        nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            defer { stopLocating(); dismiss() }
            guard let img = info[.originalImage] as? UIImage else { return }
            let baseMetadata = info[.mediaMetadata] as? [String: Any] ?? [:]
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("camera-\(UUID().uuidString).jpg")

            // Fresh fix only — a stale cached location would misplace the report.
            let loc = locationManager.location.flatMap { fix -> CLLocation? in
                fix.timestamp.timeIntervalSinceNow > -120 ? fix : nil
            }
            let heading = locationManager.heading?.trueHeading

            if ImageGPSWriter.writeJPEG(image: img, baseMetadata: baseMetadata,
                                        location: loc, heading: heading, to: url) {
                onCaptured(url)
            } else if let data = img.jpegData(compressionQuality: 0.92),
                      (try? data.write(to: url)) != nil {
                // Fallback: save without metadata rather than lose the photo.
                onCaptured(url)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            stopLocating()
            dismiss()
        }
    }
}

/// Writes a `UIImage` to a JPEG on disk, merging a GPS block (from a device
/// location fix) into the image metadata so `ExifService` can read coordinates
/// back out. Normalizes orientation to `.up` so the baked pixels match.
enum ImageGPSWriter {
    static func writeJPEG(image: UIImage, baseMetadata: [String: Any],
                          location: CLLocation?, heading: CLLocationDirection?,
                          to url: URL) -> Bool {
        guard let cg = image.normalizedUp().cgImage else { return false }

        var meta = baseMetadata
        // We redrew to `.up`; clear any orientation tags so viewers don't re-rotate.
        meta[kCGImagePropertyOrientation as String] = 1
        if var tiff = meta[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            meta[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        if let loc = location {
            var gps = meta[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
            gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
            gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
            gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
            if loc.horizontalAccuracy >= 0 {
                gps[kCGImagePropertyGPSHPositioningError as String] = loc.horizontalAccuracy
            }
            if let heading, heading >= 0 {
                gps[kCGImagePropertyGPSImgDirection as String] = heading
                gps[kCGImagePropertyGPSImgDirectionRef as String] = "T"
            }
            meta[kCGImagePropertyGPSDictionary as String] = gps
        }

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, cg, meta as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
}

private extension UIImage {
    /// Returns a copy with orientation baked into the pixels (`.up`), so a
    /// metadata-free write doesn't appear rotated.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
