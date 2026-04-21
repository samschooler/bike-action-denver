// BikeLanes/Models/StoredCase.swift
import Foundation
import SwiftData

@Model
final class StoredCase {
    var localId: UUID
    var denverInputRecordId: Int
    var denverCaseId: String?
    var denverCaseNumber: String?
    var submittedAt: Date
    var thumbnailFilename: String
    var snapshotJSON: String          // serialized ReportDraftSnapshot
    var internalStatus: String

    init(localId: UUID = UUID(),
         denverInputRecordId: Int,
         denverCaseId: String? = nil,
         denverCaseNumber: String? = nil,
         submittedAt: Date = .now,
         thumbnailFilename: String,
         snapshotJSON: String,
         internalStatus: String) {
        self.localId = localId
        self.denverInputRecordId = denverInputRecordId
        self.denverCaseId = denverCaseId
        self.denverCaseNumber = denverCaseNumber
        self.submittedAt = submittedAt
        self.thumbnailFilename = thumbnailFilename
        self.snapshotJSON = snapshotJSON
        self.internalStatus = internalStatus
    }
}

/// Codable freeze of a `ReportDraft` at submit time.
/// Kept separate so the `ReportDraft` stays non-Codable (CLLocationCoordinate2D isn't).
struct ReportDraftSnapshot: Codable {
    let addressLine1: String
    let city: String
    let state: String
    let zip: String
    let latitude: Double
    let longitude: Double
    let plate: String
    let plateState: String
    let vehicleColor: String
    let vehicleType: String
    let locationOfVehicle: String
    let blockingDriveway: Bool
    let observedAt: Date
    let notes: String
}
