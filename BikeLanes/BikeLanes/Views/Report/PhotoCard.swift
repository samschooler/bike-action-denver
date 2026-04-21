// BikeLanes/Views/Report/PhotoCard.swift
import SwiftUI

struct PhotoCard: View {
    let image: UIImage?
    let bbox: CGRect?            // normalized, Vision coordinates (origin bottom-left)
    let heading: Double?
    let onRetake: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(LinearGradient(
                    colors: [Color(red: 58/255, green: 74/255, blue: 90/255),
                             Color(red: 31/255, green: 42/255, blue: 53/255)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            // BBox overlay
            GeometryReader { geo in
                if let bbox {
                    let rect = CGRect(
                        x: bbox.minX * geo.size.width,
                        y: (1 - bbox.maxY) * geo.size.height,
                        width: bbox.width * geo.size.width,
                        height: bbox.height * geo.size.height)
                    Path { p in p.addRect(rect) }
                        .stroke(Color.green.opacity(0.9), lineWidth: 2)
                }
            }

            VStack {
                HStack(spacing: 6) {
                    chip(text: image == nil ? "WAITING" : "CAR DETECTED",
                         filled: image != nil)
                    if let heading {
                        chip(text: "heading \(compass(heading))", filled: false)
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Retake", action: onRetake)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func compass(_ deg: Double) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return dirs[max(0, min(dirs.count-1, idx))]
    }
}
