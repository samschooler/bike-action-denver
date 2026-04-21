// BikeLanes/ViewModels/HistoryViewModel.swift
import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    var cases: [StoredCase] = []
    let repo: CasePersisting

    init(repo: CasePersisting) { self.repo = repo }

    func refresh() {
        do { cases = try repo.fetchAll() } catch { cases = [] }
    }
}
