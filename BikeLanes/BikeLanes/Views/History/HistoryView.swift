// BikeLanes/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var vm: HistoryViewModel
    let auth: AuthService?
    @State private var showingLogin = false

    init(vm: HistoryViewModel, auth: AuthService? = nil) {
        self.vm = vm
        self.auth = auth
    }

    var body: some View {
        List {
            veoNotTrackedCard
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            if vm.needsSignIn {
                signedOutRow
            } else if vm.items.isEmpty && !vm.isLoading {
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
        .sheet(isPresented: $showingLogin, onDismiss: { Task { await vm.refresh() } }) {
            if let auth { LoginSheet(auth: auth) }
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

    private var veoNotTrackedCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "scooter")
                .font(.system(size: 18))
                .foregroundStyle(Color.brandGreen)
                .frame(width: 40, height: 40)
                .background(Color.leadingTile)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Veo reports aren't tracked yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("This screen shows Denver 311 cases. Tracking your Veo scooter/bike reports here is coming soon.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardStroke, lineWidth: 1))
    }

    private var signedOutRow: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Sign in to see your 311 reports")
                .font(.system(size: 17, weight: .semibold))
            Text("Denver 311 cases file under your PocketGov account. Sign in to view their status here.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingLogin = true
            } label: {
                Text("Sign in with Denver PocketGov")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12).padding(.horizontal, 20)
                    .background(Color.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowSeparator(.hidden)
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
                    .foregroundStyle(Color.dangerRed)
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
