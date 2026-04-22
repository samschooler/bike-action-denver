// BikeLanes/Views/Edit/EditVehicleSheet.swift
import SwiftUI

struct EditVehicleSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    private struct Swatch: Identifiable, Hashable {
        let name: String
        let color: Color
        let strokesBorder: Bool
        var id: String { name }
    }

    private static let swatches: [Swatch] = [
        .init(name: "White",  color: Color(red: 0.96, green: 0.96, blue: 0.94), strokesBorder: true),
        .init(name: "Silver", color: Color(red: 0.78, green: 0.78, blue: 0.80), strokesBorder: false),
        .init(name: "Gray",   color: Color(red: 0.48, green: 0.48, blue: 0.50), strokesBorder: false),
        .init(name: "Black",  color: Color(red: 0.10, green: 0.10, blue: 0.11), strokesBorder: false),
        .init(name: "Red",    color: Color(red: 0.78, green: 0.18, blue: 0.20), strokesBorder: false),
        .init(name: "Blue",   color: Color(red: 0.18, green: 0.36, blue: 0.66), strokesBorder: false),
        .init(name: "Green",  color: Color(red: 0.22, green: 0.50, blue: 0.32), strokesBorder: false),
        .init(name: "Yellow", color: Color(red: 0.92, green: 0.80, blue: 0.20), strokesBorder: false),
        .init(name: "Orange", color: Color(red: 0.93, green: 0.51, blue: 0.13), strokesBorder: false),
        .init(name: "Brown",  color: Color(red: 0.42, green: 0.28, blue: 0.18), strokesBorder: false),
        .init(name: "Gold",   color: Color(red: 0.76, green: 0.62, blue: 0.28), strokesBorder: false),
        .init(name: "Tan",    color: Color(red: 0.76, green: 0.66, blue: 0.50), strokesBorder: false),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Self.swatches) { swatch in
                                swatchButton(swatch)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    TextField("Or type a color", text: Binding(
                        get: { draft.vehicleColor ?? "" },
                        set: { draft.vehicleColor = $0 }))
                }
                Section("Type") {
                    Picker("Type", selection: $draft.vehicleType) {
                        Text("Not set").tag(DenverVehicleType?.none)
                        ForEach(DenverVehicleType.allCases, id: \.self) { t in
                            Text(t.wireValue).tag(DenverVehicleType?.some(t))
                        }
                    }
                }
                Section("Where is it parked?") {
                    Picker("Property", selection: $draft.locationOfVehicle) {
                        Text("Not set").tag(PropertyType?.none)
                        Text("Public Property").tag(PropertyType?.some(.publicProperty))
                        Text("Private Property").tag(PropertyType?.some(.privateProperty))
                    }
                    Picker("Blocking a driveway", selection: $draft.blockingDriveway) {
                        Text("Not set").tag(Bool?.none)
                        Text("No").tag(Bool?.some(false))
                        Text("Yes").tag(Bool?.some(true))
                    }
                }
            }
            .navigationTitle("Vehicle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func swatchButton(_ s: Swatch) -> some View {
        let isSelected = draft.vehicleColor?.caseInsensitiveCompare(s.name) == .orderedSame
        return Button {
            draft.vehicleColor = s.name
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(s.color)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().stroke(
                                s.strokesBorder ? Color.black.opacity(0.12) : Color.clear,
                                lineWidth: 1))
                    if isSelected {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: 46, height: 46)
                    }
                }
                .frame(width: 46, height: 46)
                Text(s.name)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
