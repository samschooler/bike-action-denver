// BikeLanes/Services/Auth/ProfileService.swift
import Foundation

/// Thin wrapper around `GET https://den.denvergov.org/api/profiles`. Needs a
/// bearer id_token; returns the user's resident profile.
struct ProfileService: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(idToken: String) async throws -> UserProfile {
        var req = URLRequest(url: DenverEndpoints.profiles)
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
        req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw ProfileError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    enum ProfileError: Error, CustomStringConvertible {
        case http(status: Int, body: String)
        var description: String {
            switch self { case .http(let s, let b): return "Profiles HTTP \(s): \(b)" }
        }
    }
}
