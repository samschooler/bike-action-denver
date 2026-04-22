// BikeLanes/Services/DenverAPI/DenverEndpoints.swift
import Foundation

enum DenverEndpoints {
    static let base = URL(string: "https://den.denvergov.org")!

    static let menus: URL = base.appending(path: "api/forms/Menus")

    static func menuQuestions(menuId: Int) -> URL {
        var c = URLComponents(url: base.appending(path: "api/forms/MenuQuestions"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "$filter",  value: "MenuId eq \(menuId) AND Active"),
            URLQueryItem(name: "$orderby", value: "Group ASC, Order ASC"),
        ]
        // Denver expects spaces as %20, not '+'; URLComponents uses %20 by default for queryItems.
        return c.url!
    }

    static func addressSearch(_ query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        // URL.appending(path:) double-encodes existing percent escapes; use relative-URL construction
        // so the pre-encoded string is preserved as-is.
        return URL(string: "api/locations/Addresses/search/denver/\(encoded)", relativeTo: base)!.absoluteURL
    }

    static func attachment(_ id: UUID) -> URL {
        base.appending(path: "api/cases/attachments/\(id.uuidString.lowercased())")
    }

    static let cases: URL = base.appending(path: "api/cases")

    /// One case's full record. Shape matches a single list-response element.
    static func caseDetail(id: Int) -> URL {
        base.appending(path: "api/cases/\(id)")
    }

    /// Lightweight per-case status check — returns a bare JSON-encoded string
    /// like `"Closed - Answer Provided"`. Useful for polling without pulling
    /// the whole record.
    static func caseStatusOnly(id: Int) -> URL {
        base.appending(path: "api/cases/casestatus/\(id)")
    }

    /// Signed-in user's case list. The server reads the caller's b2cId out of
    /// the Bearer token and scopes the response to that user — no id is in the
    /// URL. Uses OData query params for page size + sort, matching the SPA.
    static var userCases: URL {
        var c = URLComponents(url: base.appending(path: "api/cases"),
                              resolvingAgainstBaseURL: false)!
        c.queryItems = [
            URLQueryItem(name: "$top", value: "100"),
            URLQueryItem(name: "$orderby", value: "Created desc"),
        ]
        return c.url!
    }

    static let profiles: URL = base.appending(path: "api/profiles")
}
