// BikeLanes/Views/Edit/EditDateTimeSheet.swift
import SwiftUI

struct EditDateTimeSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Since when?",
                    selection: Binding(
                        get: { draft.observedAt ?? .now },
                        set: { draft.observedAt = $0 }),
                    in: ...Date.now,
                    displayedComponents: [.date])
                Text("How long has the vehicle been parked here? Pick the date you first saw it.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Observed").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if draft.observedAt == nil { draft.observedAt = .now }
            }
        }
    }
}
