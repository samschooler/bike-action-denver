// BikeLanes/Services/CaseRepository.swift
import Foundation
@preconcurrency import SwiftData

struct CaseRepository {
    let container: ModelContainer

    @discardableResult
    func save(denverInputRecordId: Int,
              denverCaseId: String?,
              denverCaseNumber: String?,
              internalStatus: String,
              thumbnailFilename: String,
              snapshot: ReportDraftSnapshot) throws -> StoredCase {
        let data = try JSONEncoder().encode(snapshot)
        let snapshotJSON = String(data: data, encoding: .utf8) ?? "{}"
        let stored = StoredCase(
            denverInputRecordId: denverInputRecordId,
            denverCaseId: denverCaseId,
            denverCaseNumber: denverCaseNumber,
            thumbnailFilename: thumbnailFilename,
            snapshotJSON: snapshotJSON,
            internalStatus: internalStatus)
        let ctx = ModelContext(container)
        ctx.insert(stored)
        try ctx.save()
        return stored
    }

    func fetchAll() throws -> [StoredCase] {
        let ctx = ModelContext(container)
        let desc = FetchDescriptor<StoredCase>(sortBy: [SortDescriptor(\.submittedAt, order: .reverse)])
        return try ctx.fetch(desc)
    }

    func deleteAll() throws {
        let ctx = ModelContext(container)
        try ctx.delete(model: StoredCase.self)
        try ctx.save()
    }
}
