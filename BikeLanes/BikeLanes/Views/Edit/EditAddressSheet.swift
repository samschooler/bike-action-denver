// BikeLanes/Views/Edit/EditAddressSheet.swift
import SwiftUI

struct EditAddressSheet: View {
    @Binding var draft: ReportDraft
    @Environment(\.dismiss) var dismiss
    @State private var query: String = ""
    @State private var matches: [DenverAddress] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    @State private var searchTask: Task<Void, Never>?
    private let api = DenverAPIClient()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(red: 250/255, green: 250/255, blue: 247/255).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    results(for: query)
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search an address", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onChange(of: query) { _, q in scheduleSearch(q) }
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !query.isEmpty {
                Button { query = ""; matches = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
    }

    @ViewBuilder
    private func results(for q: String) -> some View {
        if q.count < 4 {
            hint(text: "Type at least 4 characters to search Denver addresses.")
        } else if isSearching && matches.isEmpty {
            hint(text: "Searching…")
        } else if matches.isEmpty && hasSearched {
            hint(text: "No matches. Try a different street name or number.")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.addressId) { idx, addr in
                        resultRow(addr)
                        if idx < matches.count - 1 {
                            Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
                                .frame(height: 1).padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)
            }
        }
    }

    private func hint(text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 14)
    }

    private func resultRow(_ addr: DenverAddress) -> some View {
        Button {
            draft.resolvedAddress = addr
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                    .frame(width: 20, height: 20)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(addr.line1)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(addr.city), \(addr.state) \(addr.zip)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Debounces the search: on each keystroke we cancel the previous in-flight
    /// search and schedule a new one 250ms out.
    private func scheduleSearch(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 4 {
            matches = []
            hasSearched = false
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed)
        }
    }

    private func runSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let searched = try await api.searchAddress(
                AddressNormalizer.denverQuery(line1: q))
            if Task.isCancelled { return }
            matches = searched.map(\.toAddress)
            hasSearched = true
        } catch {
            if Task.isCancelled { return }
            matches = []
            hasSearched = true
        }
    }
}
