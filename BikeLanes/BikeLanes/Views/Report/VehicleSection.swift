// BikeLanes/Views/Report/VehicleSection.swift
import SwiftUI

/// Groups the four vehicle-related questions (color, type, parking, blocking driveway)
/// so they appear inline on the main screen. Collapses to a one-line summary with
/// an Edit button once all four are answered; Edit re-expands them.
struct VehicleSection: View {
    @Binding var draft: ReportDraft
    @State private var expanded = false

    var body: some View {
        if allSet && !expanded {
            collapsed
        } else {
            expandedView
        }
    }

    // MARK: - Collapsed

    private var collapsed: some View {
        FieldRow(
            label: "Vehicle",
            value: summary,
            caption: nil,
            missing: false,
            onEdit: { expanded = true }) {
            Circle()
                .fill(colorCategory(draft.vehicleColor))
                .frame(width: 22, height: 22)
        }
    }

    // MARK: - Expanded

    private var expandedView: some View {
        VStack(spacing: 0) {
            ColorSwatchRow(selection: $draft.vehicleColor)
            divider
            QuickPickRow(
                label: "Type",
                options: DenverVehicleType.allCases.map {
                    QuickPickOption(label: $0.shortLabel, value: $0)
                },
                selection: $draft.vehicleType)
            divider
            QuickPickRow(
                label: "Where is it parked",
                options: [
                    QuickPickOption(label: "Public", value: .publicProperty),
                    QuickPickOption(label: "Private", value: .privateProperty),
                ],
                selection: $draft.locationOfVehicle)
            divider
            QuickPickRow(
                label: "Blocking a driveway",
                options: [
                    QuickPickOption(label: "No", value: false),
                    QuickPickOption(label: "Yes", value: true),
                ],
                selection: $draft.blockingDriveway)
            if allSet {
                divider
                Button { expanded = false } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var allSet: Bool {
        draft.vehicleColor?.isEmpty == false
            && draft.vehicleType != nil
            && draft.locationOfVehicle != nil
            && draft.blockingDriveway != nil
    }

    private var summary: String {
        var parts: [String] = []
        if let c = draft.vehicleColor, !c.isEmpty { parts.append(c) }
        if let t = draft.vehicleType?.shortLabel   { parts.append(t) }
        if let loc = draft.locationOfVehicle {
            parts.append(loc == .publicProperty ? "Public" : "Private")
        }
        if let bd = draft.blockingDriveway {
            parts.append(bd ? "blocking driveway" : "not blocking")
        }
        return parts.joined(separator: " · ")
    }

    private var divider: some View {
        Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
            .frame(height: 1).padding(.horizontal, 16)
    }

    private func colorCategory(_ name: String?) -> Color {
        switch name?.lowercased() {
        case "blue":             return Color(red: 58/255, green: 90/255, blue: 154/255)
        case "red":              return Color(red: 200/255, green: 50/255, blue: 50/255)
        case "black":            return Color(red: 30/255, green: 30/255, blue: 30/255)
        case "white":            return Color(red: 240/255, green: 240/255, blue: 240/255)
        case "gray", "silver":   return Color(red: 140/255, green: 140/255, blue: 140/255)
        case "green":            return Color(red: 50/255, green: 140/255, blue: 80/255)
        case "yellow", "gold":   return Color(red: 220/255, green: 190/255, blue: 60/255)
        case "orange":           return Color(red: 235/255, green: 130/255, blue: 30/255)
        case "brown", "tan":     return Color(red: 140/255, green: 100/255, blue: 60/255)
        default:                 return Color(red: 180/255, green: 180/255, blue: 180/255)
        }
    }
}
