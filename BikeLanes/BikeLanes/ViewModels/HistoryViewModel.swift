// BikeLanes/ViewModels/HistoryViewModel.swift
import Foundation
import Observation

/// Drives the History tab. Server is the source of truth — no local storage.
/// The user's case list is fetched on appear and on pull-to-refresh, keyed
/// off the Bearer in the AuthService-provided id_token.
@MainActor
@Observable
final class HistoryViewModel {
    var items: [RemoteCase] = []
    var isLoading: Bool = false
    var lastRefreshed: Date?
    var lastError: String?

    private let status: CaseStatusService?

    init(status: CaseStatusService? = nil) {
        self.status = status
    }

    /// Pulls the latest case list from the server.
    func refresh() async {
        guard let status else { return }
        isLoading = true; defer { isLoading = false }
        do {
            items = try await status.fetchUserCases()
            lastError = nil
            lastRefreshed = .now
        } catch let CaseStatusService.Error.http(statusCode, body) {
            lastError = "Couldn't refresh (HTTP \(statusCode)). \(short(body))"
        } catch CaseStatusService.Error.notSignedIn {
            lastError = "Sign in to see your reports."
            items = []
        } catch {
            lastError = "Couldn't refresh: \(error.localizedDescription)"
        }
    }

    private func short(_ body: String) -> String {
        if body.count <= 120 { return body }
        return String(body.prefix(120)) + "…"
    }
}
