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
    private let auth: AuthService?

    init(status: CaseStatusService? = nil, auth: AuthService? = nil) {
        self.status = status
        self.auth = auth
    }

    /// Pulls the latest case list from the server.
    func refresh() async {
        // Demo mode (App Store review) — serve canned cases, skip the network.
        if auth?.isDemoMode == true {
            items = Self.demoCases
            lastRefreshed = .now
            lastError = nil
            return
        }
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

    /// Canned history list shown in demo mode so reviewers see a realistic
    /// range of statuses without touching Denver's real 311 system.
    private static let demoCases: [RemoteCase] = [
        RemoteCase.demo(id: 900_101, title: "Illegal Parking",
                        caseStatus: "Closed - Answer Provided",
                        internalCaseStatus: "processed",
                        caseNumber: 99_100_001,
                        resolutionNotes: "Vehicle gone on arrival (no violation found)",
                        created: .now.addingTimeInterval(-86_400 * 6),
                        closed: .now.addingTimeInterval(-86_400 * 5)),
        RemoteCase.demo(id: 900_102, title: "Illegal Parking",
                        caseStatus: "In Progress",
                        internalCaseStatus: "processed",
                        caseNumber: 99_100_002,
                        resolutionNotes: nil,
                        created: .now.addingTimeInterval(-3_600 * 5),
                        closed: nil),
        RemoteCase.demo(id: 900_103, title: "Illegal Parking",
                        caseStatus: "New",
                        internalCaseStatus: "queuedForCRM",
                        caseNumber: nil,
                        resolutionNotes: nil,
                        created: .now.addingTimeInterval(-60 * 20),
                        closed: nil),
    ]

    private func short(_ body: String) -> String {
        if body.count <= 120 { return body }
        return String(body.prefix(120)) + "…"
    }
}
