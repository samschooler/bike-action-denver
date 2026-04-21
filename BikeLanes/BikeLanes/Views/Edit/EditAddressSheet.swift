// BikeLanes/Views/Edit/EditAddressSheet.swift
import SwiftUI

struct EditAddressSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss
    @State private var query: String = ""
    @State private var results: [DenverAddress] = []
    private let api = DenverAPIClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Start typing an address…", text: $query)
                    .padding()
                    .onChange(of: query) { _, q in Task { await runSearch(q) } }
                List {
                    ForEach(results, id: \.addressId) { addr in
                        Button {
                            draft.resolvedAddress = addr
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(addr.line1).font(.body)
                                Text("\(addr.city), \(addr.state) \(addr.zip)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Address").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { query = draft.resolvedAddress?.line1 ?? "" }
        }
    }

    private func runSearch(_ q: String) async {
        guard q.count >= 4 else { results = []; return }
        do {
            let searched = try await api.searchAddress(
                AddressNormalizer.denverQuery(line1: q))
            results = searched.map(\.toAddress)
        } catch {
            results = []
        }
    }
}
