// BikeLanes/Views/Report/CameraPicker.swift
import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIImagePickerController` with `sourceType = .camera`.
/// PhotosPicker covers the library case, but there is no SwiftUI-native camera
/// control yet — so we bridge to UIKit for the capture path.
///
/// Returns a JPEG-encoded photo written to a temp file so the rest of the
/// pipeline (ExifService, VehicleDetector, …) can consume it as `URL`.
struct CameraPicker: UIViewControllerRepresentable {
    let onCaptured: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
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

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCaptured: (URL) -> Void
        let dismiss: () -> Void

        init(onCaptured: @escaping (URL) -> Void, dismiss: @escaping () -> Void) {
            self.onCaptured = onCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            defer { dismiss() }
            guard let img = info[.originalImage] as? UIImage,
                  let data = img.jpegData(compressionQuality: 0.92) else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("camera-\(UUID().uuidString).jpg")
            do {
                try data.write(to: url)
                onCaptured(url)
            } catch {
                // If temp write fails we silently drop — user can just retake.
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
