// BikeLanes/Views/Edit/EditPlateSheet.swift
import SwiftUI

struct EditPlateSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let url = draft.plateCropImageURL,
                   let ui = UIImage(contentsOfFile: url.path) {
                    Section {
                        Image(uiImage: ui)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }
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
