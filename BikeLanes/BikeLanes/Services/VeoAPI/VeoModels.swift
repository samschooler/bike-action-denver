// BikeLanes/Services/VeoAPI/VeoModels.swift
import Foundation

/// Percent-encodes a string for application/x-www-form-urlencoded bodies.
/// Only RFC 3986 unreserved characters pass through; everything else (incl.
/// space -> %20) is percent-encoded. Rails/Zendesk decode %20 as space.
func veoFormEncode(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
}

/// Escapes HTML metacharacters. The Veo submit sends `description_mimetype:
/// text/html` (confirmed in the HAR), so raw user notes must be escaped or `&`,
/// `<`, `>` would render broken or inject markup into the Zendesk ticket.
func veoHTMLEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")   // must be first
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
}

struct VeoAttachment: Decodable, Sendable {
    let id: String
    let fileName: String
    let url: String
    let deleteURL: String
    /// Raw JSON body as returned by the upload call; set by the client after decode.
    var rawJSON: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case url
        case deleteURL = "delete_url"
    }
}

struct VeoSubmission: Sendable {
    let draft: VeoReportDraft
    let profile: VeoProfile
    let attachmentJSON: String
    let csrfToken: String

    /// Builds the exact `request[...]` form body per docs/veo-report-api.md.
    func formURLEncodedBody() -> String {
        // Send exactly what the user typed/scanned; leave the field empty if they
        // didn't. "(Didn't find it)" is only a UI placeholder, never submitted.
        let vehicleNumber = draft.vehicleNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateTag = (draft.onPrivateOrBlocking ?? false) ? "illegal_parking_yes" : "illegal_parking_no"
        let rampTag    = (draft.blockingRamp ?? false) ? "block_ramp_yes" : "block_ramp_no"
        let descriptionHTML = "<p>\(veoHTMLEscape(draft.notes))</p>"

        func cf(_ id: String) -> String { "request[custom_fields][\(id)]" }

        let pairs: [(String, String)] = [
            ("utf8", "\u{2713}"),
            ("request[ticket_form_id]", VeoEndpoints.ticketFormID),
            ("request[anonymous_requester_email]", profile.email),
            ("request[subject]", VeoEndpoints.subject),
            ("request[description]", descriptionHTML),
            ("request[description_mimetype]", VeoEndpoints.descriptionMimeType),
            (cf(VeoEndpoints.Field.phone), profile.phoneDigits),
            (cf(VeoEndpoints.Field.vehicleNumber), vehicleNumber),
            (cf(VeoEndpoints.Field.vehicleType), draft.vehicleType?.wireValue ?? ""),
            (cf(VeoEndpoints.Field.market), VeoEndpoints.market),
            (cf(VeoEndpoints.Field.fullName), profile.name),
            (cf(VeoEndpoints.Field.location), draft.addressText),
            (cf(VeoEndpoints.Field.privateBlocking), privateTag),
            (cf(VeoEndpoints.Field.blockingRamp), rampTag),
            ("request[attachments][]", attachmentJSON),
            ("authenticity_token", csrfToken),
        ]
        return pairs
            .map { "\(veoFormEncode($0.0))=\(veoFormEncode($0.1))" }
            .joined(separator: "&")
    }
}
