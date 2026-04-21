// BikeLanes/Views/Edit/EditVehicleSheet.swift
import SwiftUI

struct EditVehicleSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Color") {
                    TextField("Blue", text: Binding(
                        get: { draft.vehicleColor ?? "" },
                        set: { draft.vehicleColor = $0 }))
                }
                Section("Type") {
                    Picker("Type", selection: Binding(
                        get: { draft.vehicleType ?? .sedan },
                        set: { draft.vehicleType = $0 })) {
                        ForEach(DenverVehicleType.allCases, id: \.self) { t in
                            Text(t.wireValue).tag(t)
                        }
                    }
                }
                Section("Where is it parked?") {
                    Picker("Property", selection: Binding(
                        get: { draft.locationOfVehicle ?? .publicProperty },
                        set: { draft.locationOfVehicle = $0 })) {
                        Text("Public Property").tag(PropertyType.publicProperty)
                        Text("Private Property").tag(PropertyType.privateProperty)
                    }
                    Toggle("Blocking a driveway", isOn: Binding(
                        get: { draft.blockingDriveway ?? false },
                        set: { draft.blockingDriveway = $0 }))
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
}
