// BikeLanes/Views/Edit/EditPlateSheet.swift
import SwiftUI

struct EditPlateSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Plate") {
                    TextField("ABC123", text: Binding(
                        get: { draft.plate ?? "" },
                        set: { draft.plate = $0.uppercased() }))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                }
                Section("State") {
                    Picker("State", selection: Binding(
                        get: { draft.plateState ?? .colorado },
                        set: { draft.plateState = $0 })) {
                        ForEach(USState.allCases, id: \.self) { state in
                            Text(state.display).tag(state)
                        }
                    }
                }
            }
            .navigationTitle("Plate").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
