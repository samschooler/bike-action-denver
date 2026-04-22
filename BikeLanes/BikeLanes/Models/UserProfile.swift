// BikeLanes/Models/UserProfile.swift
import Foundation

/// Decoded shape of `GET https://den.denvergov.org/api/profiles`.
/// Only the fields we actually use are strictly required; the rest tolerate nulls.
struct UserProfile: Codable, Equatable, Sendable {
    /// B2C object id — same value as `id_token.sub`. Required for case submission's
    /// `contact.b2cId` field.
    let id: String
    let firstName: String?
    let lastName: String?
    let displayName: String?
    let email: String?
    let phone: String?
    let preferredLanguage: String?

    /// Best-effort human-readable name for UI.
    var displayLabel: String {
        if let f = firstName, let l = lastName, !f.isEmpty { return "\(f) \(l.first.map { String($0) + "." } ?? "")".trimmingCharacters(in: .whitespaces) }
        if let f = firstName, !f.isEmpty { return f }
        if let d = displayName, !d.isEmpty { return d }
        if let e = email, !e.isEmpty { return e }
        return "signed in"
    }
}
