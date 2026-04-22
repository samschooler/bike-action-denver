// BikeLanes/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var vm: HistoryViewModel
    let auth: AuthService?

    init(vm: HistoryViewModel, auth: AuthService? = nil) {
        self.vm = vm
        self.auth = auth
    }

    var body: some View {
        List {
            if vm.items.isEmpty && !vm.isLoading {
                emptyRow
            } else {
                ForEach(vm.items) { item in
                    NavigationLink(value: item) {
                        HistoryRow(item: item)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Reports")
        .navigationDestination(for: RemoteCase.self) { item in
            CaseDetailView(item: item, auth: auth)
        }
        .refreshable { await vm.refresh() }
        .onAppear {
            Task { await vm.refresh() }
        }
        .safeAreaInset(edge: .bottom) {
            if vm.lastRefreshed != nil || vm.lastError != nil {
                footerBar
            }
        }
        .overlay {
            if vm.isLoading && vm.items.isEmpty {
                ProgressView().controlSize(.large)
            }
        }
    }

    private var emptyRow: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No reports yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Cases you submit — from this app, the web, or PocketGov — will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .listRowSeparator(.hidden)
    }

    private var footerBar: some View {
        HStack {
            if let err = vm.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                Text(err).lineLimit(2)
            } else if let last = vm.lastRefreshed {
                Text("Updated \(relative(last))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if vm.isLoading { ProgressView().controlSize(.small) }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func relative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: .now)
    }
}
