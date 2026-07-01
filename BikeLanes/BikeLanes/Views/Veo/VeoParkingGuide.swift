// BikeLanes/Views/Veo/VeoParkingGuide.swift
import SwiftUI

/// Shown on the Veo report screen's empty state (below the photo pickers) to
/// help the reporter judge whether a scooter/bike is actually parked improperly.
/// Illustrations + rules are Veo's own, from veoride.com/parking-styles.
struct VeoParkingGuide: View {
    private struct Style: Identifiable {
        let id = UUID()
        let image: String
        let title: String
        let rule: String
    }

    private let styles: [Style] = [
        .init(image: "VeoParkFreeFloating", title: "Free floating",
              rule: "Parked upright, with enough room left for a wheelchair or stroller to pass — never blocking the sidewalk, a ramp, or a doorway."),
        .init(image: "VeoParkZone", title: "Mandatory parking zone",
              rule: "In a marked corral (look for the “P” in the Veo app), on the sidewalk or where cars park. Keep it clean, clear, and upright."),
        .init(image: "VeoParkCableLock", title: "Cable lock",
              rule: "Secured with its own cable lock to a bike rack or sign post at the end of the ride."),
    ]

    private let redFlags: [String] = [
        "Tipped over or not standing upright",
        "Blocking the sidewalk, a wheelchair ramp, or a curb cut",
        "Blocking a crosswalk, driveway, bus stop, or parking space",
        "Left in the street / a travel lane, or blocking transit",
        "Dumped on private property or outside the service area",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("What proper parking looks like")

            ForEach(styles) { style in
                VStack(alignment: .leading, spacing: 8) {
                    Image(style.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color.cardBackgroundAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(style.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(style.rule)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.cardStroke, lineWidth: 1))
            }

            header("Signs it's improperly parked")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(redFlags, id: \.self) { flag in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dangerRed)
                            .padding(.top, 1)
                        Text(flag)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardStroke, lineWidth: 1))

            Text("Illustrations and rules from Veo (veoride.com/parking-styles).")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.8)
            .foregroundStyle(Color.mutedLabel)
    }
}
