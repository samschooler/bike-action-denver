// BikeLanes/Views/Report/PhotoCard.swift
import SwiftUI
import MapKit
import CoreLocation

struct PhotoCard: View {
    let image: UIImage?
    let bbox: CGRect?            // Car bbox — normalized, Vision coordinates (origin bottom-left)
    let plateBBox: CGRect?       // Plate bbox — same coord system
    let plateStatus: String?     // UI diagnostic from plate detector (e.g. "plate 31.2%")
    let heading: Double?
    let coordinate: CLLocationCoordinate2D?
    let onTakePhoto: () -> Void
    let onChoosePhoto: () -> Void

    /// Whether the map currently occupies the main area. Picture-in-picture swaps:
    /// tapping the thumbnail in the bottom-left promotes it to primary.
    @State private var mapPrimary = false

    /// Aspect ratio of the card. Matches the photo so switching to the map doesn't
    /// change the card's size. Falls back to 4:3 before a photo is loaded.
    private var cardAspect: CGFloat {
        guard let image, image.size.height > 0 else { return 4.0 / 3.0 }
        return max(0.4, min(2.5, image.size.width / image.size.height))
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            primary
            if coordinate != nil, image != nil {
                pip.padding(14)
            }
        }
        .aspectRatio(cardAspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: mapPrimary)
    }

    // MARK: - Primary

    @ViewBuilder
    private var primary: some View {
        if mapPrimary, let coord = coordinate {
            fullMap(coord)
        } else {
            photoPrimary
        }
    }

    private var photoPrimary: some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholderGradient
            }
            GeometryReader { geo in
                if let bbox {
                    Path { p in p.addRect(Self.visionRect(bbox, in: geo.size)) }
                        .stroke(Color.green.opacity(0.9), lineWidth: 2)
                }
                if let plateBBox {
                    Path { p in p.addRect(Self.visionRect(plateBBox, in: geo.size)) }
                        .stroke(Color.yellow, lineWidth: 3)
                }
            }
            VStack {
                HStack(spacing: 6) {
                    chip(text: image == nil ? "WAITING" : "CAR DETECTED", filled: image != nil)
                    if let heading { chip(text: "heading \(compass(heading))", filled: false) }
                    if let plateStatus { chip(text: plateStatus, filled: false) }
                }
                Spacer()
                HStack {
                    Spacer()
                    Menu {
                        Button { onTakePhoto() } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        Button { onChoosePhoto() } label: {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Text("New Photo")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
        }
    }

    private func fullMap(_ coord: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .camera(MapCamera(
            centerCoordinate: coord, distance: 400, heading: 0, pitch: 0))) {
            Marker("", coordinate: coord)
                .tint(Color(red: 179/255, green: 58/255, blue: 58/255))
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    // MARK: - Picture-in-picture thumbnail

    @ViewBuilder
    private var pip: some View {
        if mapPrimary {
            photoThumb
        } else if let coord = coordinate {
            mapThumb(coord)
        }
    }

    private var photoThumb: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else         { placeholderGradient }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.9), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { mapPrimary = false }
    }

    private func mapThumb(_ coord: CLLocationCoordinate2D) -> some View {
        // Oversize the Map so its "Legal" attribution (bottom-right) falls outside
        // the clipped 72×72 region. The pin stays centered because the oversized
        // frame is centered within the outer frame.
        Map(initialPosition: .camera(MapCamera(
            centerCoordinate: coord, distance: 300, heading: 0, pitch: 0))) {
            Marker("", coordinate: coord)
                .tint(Color(red: 179/255, green: 58/255, blue: 58/255))
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(width: 120, height: 120)
        .offset(y: 10)                 // nudges the map so Marker's balloon (which sits above its tip) is visually centered
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.9), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { mapPrimary = true }
    }

    // MARK: - Helpers

    private var placeholderGradient: some View {
        Rectangle().fill(LinearGradient(
            colors: [Color(red: 58/255, green: 74/255, blue: 90/255),
                     Color(red: 31/255, green: 42/255, blue: 53/255)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func chip(text: String, filled: Bool) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(filled
                ? Color(red: 42/255, green: 111/255, blue: 63/255).opacity(0.9)
                : Color.white.opacity(0.15))
            .clipShape(Capsule())
    }

    private static func visionRect(_ bbox: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: bbox.minX * size.width,
               y: (1 - bbox.maxY) * size.height,
               width: bbox.width * size.width,
               height: bbox.height * size.height)
    }

    private func compass(_ deg: Double) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[max(0, min(dirs.count-1, idx))]
    }
}
