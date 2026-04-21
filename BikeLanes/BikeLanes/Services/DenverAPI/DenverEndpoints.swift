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
}
