// BikeLanes/Views/Edit/EditDateTimeSheet.swift
import SwiftUI

struct EditDateTimeSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Observed at", selection: Binding(
                    get: { draft.observedAt ?? .now },
                    set: { draft.observedAt = $0 }))
            }
            .navigationTitle("Observed").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
