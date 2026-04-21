// BikeLanes/Views/Edit/EditNotesSheet.swift
import SwiftUI

struct EditNotesSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextEditor(text: Binding(
                    get: { draft.notes ?? "" },
                    set: { draft.notes = $0 }))
                .frame(minHeight: 200)
            }
            .navigationTitle("Notes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
