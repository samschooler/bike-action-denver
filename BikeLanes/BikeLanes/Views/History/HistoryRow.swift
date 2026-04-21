// BikeLanes/Views/History/HistoryRow.swift
import SwiftUI

struct HistoryRow: View {
    let stored: StoredCase

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshotLine1).font(.body)
                Text(stored.submittedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                Text("Case #\(stored.denverInputRecordId) · \(stored.internalStatus)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var snapshotLine1: String {
        guard let d = stored.snapshotJSON.data(using: .utf8),
              let snap = try? JSONDecoder().decode(ReportDraftSnapshot.self, from: d) else {
            return "Report"
        }
        return snap.addressLine1
    }
}
