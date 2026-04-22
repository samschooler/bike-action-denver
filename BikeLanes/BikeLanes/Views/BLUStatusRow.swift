// BikeLanes/Views/BLUStatusRow.swift
import SwiftUI

/// Shared UI surface for the Bike Lane Uprising fan-out state of a single
/// Denver case. Shown on the submit receipt screen and (read-only variant)
/// on history detail. Returns an empty view when there's no mirror entry
/// for the case — BLU mirror is opt-in and most cases won't have one.
struct BLUStatusRow: View {
    let mirror: BLUCaseMirror
    let caseId: Int
    /// Optional retry hook. When nil, no retry button is rendered even if
    /// the case is in `.failed`. CaseDetailView omits it because the retry
    /// context (photo bytes + draft) only lives in memory for the current
    /// submit session.
    let onRetry: (() -> Void)?
    /// True when the VM still has the draft + photo needed to retry. Used
    /// to hide the Retry button if the context was dropped (e.g. user
    /// started a new report before we failed).
    let canRetry: Bool

    init(mirror: BLUCaseMirror, caseId: Int,
         canRetry: Bool = false, onRetry: (() -> Void)? = nil) {
        self.mirror = mirror
        self.caseId = caseId
        self.canRetry = canRetry
        self.onRetry = onRetry
    }

    var body: some View {
        if let entry = mirror.status(for: caseId) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BIKE LANE UPRISING")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
                statusLine(entry)
                if let err = entry.errorMessage, entry.status == .failed {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if entry.status == .failed, canRetry, let onRetry {
                    Button("Retry submission to BLU") { onRetry() }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(background(for: entry.status))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func statusLine(_ entry: BLUCaseMirrorEntry) -> some View {
        switch entry.status {
        case .pending:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Mirroring to Bike Lane Uprising…")
                    .font(.system(size: 14))
            }
        case .sent:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                Text("Mirrored to Bike Lane Uprising")
                    .font(.system(size: 14))
            }
        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                Text("Couldn't send to Bike Lane Uprising")
                    .font(.system(size: 14))
            }
        }
    }

    private func background(for status: BLUCaseMirrorEntry.Status) -> Color {
        switch status {
        case .pending: return Color(red: 239/255, green: 236/255, blue: 226/255)
        case .sent:    return Color(red: 231/255, green: 244/255, blue: 232/255)
        case .failed:  return Color(red: 250/255, green: 230/255, blue: 230/255)
        }
    }
}
