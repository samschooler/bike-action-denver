// BikeLanesTests/CaseRepositoryTests.swift
import XCTest
import SwiftData
@testable import BikeLanes

final class CaseRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: StoredCase.self, configurations: config)
    }

    func testSaveAndFetch() throws {
        let repo = CaseRepository(container: container)
        let snap = ReportDraftSnapshot(
            addressLine1: "2744 W 13th Ave", city: "Denver", state: "CO", zip: "80204",
            latitude: 39.7363, longitude: -105.0215,
            plate: "ABC123", plateState: "CO",
            vehicleColor: "Blue", vehicleType: "Sedan (4 Door)",
            locationOfVehicle: "Public Property", blockingDriveway: false,
            observedAt: .now, notes: "")
        let saved = try repo.save(
            denverInputRecordId: 266869, denverCaseId: nil, denverCaseNumber: nil,
            internalStatus: "queuedForCRM", thumbnailFilename: "a.jpg", snapshot: snap)
        XCTAssertEqual(saved.denverInputRecordId, 266869)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.localId, saved.localId)
    }
}
