// BikeLanes/Views/History/HistoryRow.swift
import SwiftUI

struct HistoryRow: View {
    let item: RemoteCase

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                if let created = item.created {
                    Text(created, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            statusPill
        }
    }

    private var subtitle: String {
        if let n = item.caseNumber { return "Case \(n)" }
        return "Denver #\(item.id)"
    }

    private var statusPill: some View {
        Text(item.displayStatus)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(statusBackground)
            .clipShape(Capsule())
    }

    private var statusForeground: Color {
        let s = item.displayStatus.lowercased()
        if s.contains("closed") { return .white }
        if s.contains("new") || s.contains("processed") || s.contains("queued") {
            return Color(red: 42/255, green: 111/255, blue: 63/255)
        }
        return .secondary
    }

    private var statusBackground: Color {
        let s = item.displayStatus.lowercased()
        if s.contains("closed") { return Color(red: 42/255, green: 111/255, blue: 63/255) }
        if s.contains("new") || s.contains("processed") || s.contains("queued") {
            return Color(red: 231/255, green: 244/255, blue: 232/255)
        }
        return Color(red: 239/255, green: 236/255, blue: 226/255)
    }
}
