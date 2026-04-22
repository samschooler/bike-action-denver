// BikeLanes/Views/CaseDetailView.swift
import SwiftUI

struct CaseDetailView: View {
    let initialItem: RemoteCase
    let auth: AuthService?

    @State private var fresh: RemoteCase?
    @State private var isRefreshing = false
    @State private var refreshError: String?

    init(item: RemoteCase, auth: AuthService? = nil) {
        self.initialItem = item
        self.auth = auth
    }

    private var current: RemoteCase { fresh ?? initialItem }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = thumbnailURL, let auth {
                    AuthedImage(url: url, auth: auth)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 239/255, green: 236/255, blue: 226/255))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 20)
                }

                header
                    .padding(.horizontal, 20)

                if let notes = current.resolutionNotes, !notes.isEmpty {
                    calloutCard(
                        title: "Denver's response",
                        body: notes,
                        tint: Color(red: 231/255, green: 244/255, blue: 232/255))
                        .padding(.horizontal, 20)
                }

                metadataCard
                    .padding(.horizontal, 20)

                if let err = refreshError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }

                Link(destination: URL(string:
                    "https://www.denvergov.org/myprofile/home/cases/\(current.id)")!) {
                    HStack {
                        Text("View on Denvergov.org")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Color(red: 250/255, green: 250/255, blue: 247/255))
        .navigationTitle("Case #\(current.id)")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(current.displayTitle)
                .font(.system(size: 22, weight: .semibold))
            HStack(spacing: 8) {
                statusPill
                if let n = current.caseNumber { Text("SF \(n)").font(.system(size: 12)).foregroundStyle(.secondary) }
                if isRefreshing { ProgressView().controlSize(.small) }
            }
        }
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            if let d = current.created {
                row("Submitted", d.formatted(date: .abbreviated, time: .shortened))
            }
            if let d = current.closed {
                divider
                row("Closed", d.formatted(date: .abbreviated, time: .shortened))
            }
            if let n = current.caseNumber {
                divider
                row("Case number", String(n))
            }
            if let s = current.caseId {
                divider
                row("Salesforce ID", s)
            }
            divider
            row("Denver ID", "\(current.id)")
            if let internalStatus = current.internalCaseStatus,
               internalStatus.caseInsensitiveCompare(current.displayStatus) != .orderedSame {
                divider
                row("Internal status", internalStatus)
            }
            if let sent = current.sentStatus {
                divider
                row("Sent status", sent)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
    }

    private func calloutCard(title: String, body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
            .frame(height: 1).padding(.horizontal, 16)
    }

    private var statusPill: some View {
        Text(current.displayStatus)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(statusBackground)
            .clipShape(Capsule())
    }

    private var statusForeground: Color {
        let s = current.displayStatus.lowercased()
        if s.contains("closed") { return .white }
        if s.contains("new") || s.contains("processed") || s.contains("queued") {
            return Color(red: 42/255, green: 111/255, blue: 63/255)
        }
        return .secondary
    }

    private var statusBackground: Color {
        let s = current.displayStatus.lowercased()
        if s.contains("closed") { return Color(red: 42/255, green: 111/255, blue: 63/255) }
        if s.contains("new") || s.contains("processed") || s.contains("queued") {
            return Color(red: 231/255, green: 244/255, blue: 232/255)
        }
        return Color(red: 239/255, green: 236/255, blue: 226/255)
    }

    private var thumbnailURL: URL? {
        guard let id = current.attachmentId, !id.isEmpty else { return nil }
        return URL(string: "https://den.denvergov.org/api/cases/attachments/thumbnail/\(id)")
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let auth else { return }
        let svc = CaseStatusService(tokenProvider: { try await auth.currentIdToken() })
        isRefreshing = true; defer { isRefreshing = false }
        do {
            fresh = try await svc.fetchCase(id: initialItem.id)
            refreshError = nil
        } catch {
            refreshError = "Couldn't refresh case: \(error.localizedDescription)"
        }
    }
}
