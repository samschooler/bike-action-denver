// BikeLanes/Models/RemoteCase.swift
import Foundation

/// Shape of one record returned by `GET /api/cases?$top=100&$orderby=Created desc`
/// (list) and `GET /api/cases/{id}` (detail). Both endpoints return the same
/// flat object — neither includes address/location, so the row title defaults
/// to the case category (`title`, e.g. "Illegal Parking").
struct RemoteCase: Decodable, Hashable, Sendable, Identifiable {
    let id: Int                   // Denver primary key — used in `/myprofile/home/cases/{id}`
    let inputRecordId: Int?
    let attachmentId: String?     // thumbnail lookup key
    let menuId: Int?
    let title: String?            // e.g. "Illegal Parking"
    let email: String?
    let b2CId: String?
    let created: Date?
    let closed: Date?
    let internalCaseStatus: String?   // machine value ("processed", "queuedForCRM")
    let caseStatus: String?           // user-facing ("Closed - Answer Provided")
    let caseId: String?               // Salesforce object id
    let caseNumber: Int?              // Salesforce-visible case number
    let resolutionNotes: String?
    let sentStatus: String?

    /// Best-effort short label for the row.
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return "Case #\(id)"
    }

    /// User-facing status — prefers the human label.
    var displayStatus: String {
        if let s = caseStatus, !s.isEmpty { return s }
        if let s = internalCaseStatus, !s.isEmpty { return s }
        return "Unknown"
    }

    // MARK: - Decoding

    /// Factory for demo / preview instances (App Store reviewer mode).
    static func demo(id: Int,
                     title: String,
                     caseStatus: String,
                     internalCaseStatus: String,
                     caseNumber: Int?,
                     resolutionNotes: String?,
                     created: Date?,
                     closed: Date?) -> RemoteCase {
        // Construct via JSON so the memberwise init doesn't need to exist.
        let payload: [String: Any] = [
            "id": id,
            "inputRecordId": id - 10,
            "attachmentId": NSNull(),
            "menuId": 10,
            "title": title,
            "email": "apple@sam.ink",
            "b2CId": "demo-apple-reviewer",
            "created": iso8601(created),
            "closed": closed.map(iso8601) ?? NSNull(),
            "internalCaseStatus": internalCaseStatus,
            "caseStatus": caseStatus,
            "caseId": NSNull(),
            "caseNumber": caseNumber ?? NSNull(),
            "resolutionNotes": resolutionNotes ?? NSNull(),
            "sentStatus": "sent",
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! decode(from: data)
    }

    private static func iso8601(_ d: Date?) -> Any {
        guard let d else { return NSNull() }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    static func decodeArray(from data: Data) throws -> [RemoteCase] {
        try decoder.decode([RemoteCase].self, from: data)
    }

    static func decode(from data: Data) throws -> RemoteCase {
        try decoder.decode(RemoteCase.self, from: data)
    }

    /// Denver returns fractional seconds with up to 7 digits (e.g.
    /// `2026-04-21T20:57:12.6243207+00:00`). iOS's `ISO8601DateFormatter` only
    /// parses 3-digit fractions, so we normalize the string before parsing and
    /// fall back to the non-fractional variant for timestamps like `closed`
    /// which sometimes come without any fractional component.
    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseDenverISO(raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unparseable date: \(raw)")
        }
        return d
    }

    static func parseDenverISO(_ raw: String) -> Date? {
        // Clip fractional seconds to at most 3 digits, since iOS's parser caps there.
        var normalized = raw
        if let range = raw.range(of: #"\.[0-9]+"#, options: .regularExpression) {
            let frac = String(raw[range].dropFirst())
            let clipped = String(frac.prefix(3))
            normalized.replaceSubrange(range, with: "." + clipped)
        }
        // ISO8601DateFormatter isn't Sendable; instantiate per call — it's cheap
        // and only hit a handful of times per list refresh.
        let ms = ISO8601DateFormatter()
        ms.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = ms.date(from: normalized) { return d }
        let s = ISO8601DateFormatter()
        s.formatOptions = [.withInternetDateTime]
        if let d = s.date(from: normalized) { return d }
        if let d = s.date(from: raw) { return d }
        return nil
    }
}
