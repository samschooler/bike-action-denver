// BikeLanes/Views/CaseDetailView.swift
import SwiftUI

struct CaseDetailView: View {
    let stored: StoredCase

    var body: some View {
        Form {
            Section("Denver") {
                LabeledContent("Case", value: "#\(stored.denverInputRecordId)")
                LabeledContent("Status", value: stored.internalStatus)
                if let cn = stored.denverCaseNumber { LabeledContent("SF #", value: cn) }
                LabeledContent("Submitted", value: stored.submittedAt.formatted())
            }
            if let snap = snapshot {
                Section("Report") {
                    LabeledContent("Address", value: "\(snap.addressLine1), \(snap.city)")
                    LabeledContent("Plate", value: "\(snap.plate) \(snap.plateState)")
                    LabeledContent("Vehicle", value: "\(snap.vehicleColor) \(snap.vehicleType)")
                    LabeledContent("Blocking driveway",
                                   value: snap.blockingDriveway ? "Yes" : "No")
                }
            }
            Section {
                Link("View on Denvergov.org",
                     destination: URL(string:
                        "https://www.denvergov.org/myprofile/home/cases/\(stored.denverInputRecordId)")!)
            }
        }
        .navigationTitle("Case #\(stored.denverInputRecordId)")
    }

    private var snapshot: ReportDraftSnapshot? {
        guard let d = stored.snapshotJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ReportDraftSnapshot.self, from: d)
    }
}
