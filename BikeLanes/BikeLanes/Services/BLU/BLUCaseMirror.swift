// BikeLanes/Services/BLU/BLUCaseMirror.swift
import Foundation
import Observation

/// Per-case BLU submission state, mirrored locally keyed by Denver case id.
/// BLU has no concept of our Denver cases and returns no identifier we could
/// use to look up a report later — we only get an HTTP 200. This local
/// mirror is the only way the UI can know which Denver case was also sent
/// to BLU, when, and whether it failed.
///
/// Persisted to UserDefaults (not Keychain) — contains no credentials, just
/// a tiny state machine per case.
struct BLUCaseMirrorEntry: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending
        case sent
        case failed
    }
    var status: Status
    var updatedAt: Date
    var errorMessage: String?
}

@MainActor
@Observable
final class BLUCaseMirror {
    /// caseId → state. Kept small — oldest entries ageing out is a future
    /// problem; a user would need to file thousands of reports before this
    /// plist hit any real size.
    private(set) var byCaseId: [Int: BLUCaseMirrorEntry] = [:]

    private let defaults: UserDefaults
    private let key = "blu.caseMirror"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Int: BLUCaseMirrorEntry].self, from: data) {
            self.byCaseId = decoded
        }
    }

    func set(_ entry: BLUCaseMirrorEntry, for caseId: Int) {
        byCaseId[caseId] = entry
        persist()
    }

    func status(for caseId: Int) -> BLUCaseMirrorEntry? { byCaseId[caseId] }

    private func persist() {
        if let data = try? JSONEncoder().encode(byCaseId) {
            defaults.set(data, forKey: key)
        }
    }
}
