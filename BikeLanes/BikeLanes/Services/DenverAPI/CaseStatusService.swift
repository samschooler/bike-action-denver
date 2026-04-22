// BikeLanes/Services/DenverAPI/CaseStatusService.swift
import Foundation

/// Fetches the signed-in user's case list and individual case detail from Denver.
/// Both endpoints are **unverified** — the source HAR didn't capture a list call
/// and only inferred `GET /api/cases/{id}` from the SPA's URL shape. Callers are
/// expected to treat failures as a cache miss and keep showing the local store.
struct CaseStatusService: Sendable {
    typealias TokenProvider = @Sendable () async throws -> String?
    typealias InvalidateHandler = @Sendable () async -> Void

    let session: URLSession
    let tokenProvider: TokenProvider
    /// Called when Denver returns 401 — AuthService uses this to drop its tokens
    /// so the UI flips back to the sign-in prompt.
    let onInvalidated: InvalidateHandler?

    init(session: URLSession = .shared,
         tokenProvider: @escaping TokenProvider,
         onInvalidated: InvalidateHandler? = nil) {
        self.session = session
        self.tokenProvider = tokenProvider
        self.onInvalidated = onInvalidated
    }

    /// Fetches the signed-in user's full case list. Tries the simplest REST
    /// shape (`GET /api/cases`) first; tolerates a variety of response shapes
    /// via `RemoteCase.decodeArray`.
    func fetchUserCases() async throws -> [RemoteCase] {
        let data = try await authedGET(DenverEndpoints.userCases)
        return try RemoteCase.decodeArray(from: data)
    }

    /// Fetches one case by Denver primary key (the top-level `id` from submit).
    func fetchCase(id: Int) async throws -> RemoteCase {
        let data = try await authedGET(DenverEndpoints.caseDetail(id: id))
        return try RemoteCase.decode(from: data)
    }

    // MARK: - Request

    private func authedGET(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
        req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw Error.notSignedIn
        }
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
        if status == 401 || status == 403 {
            await onInvalidated?()
        }
        guard (200...299).contains(status) else {
            throw Error.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    enum Error: Swift.Error, CustomStringConvertible {
        case notSignedIn
        case http(status: Int, body: String)
        case decode(String)
        var description: String {
            switch self {
            case .notSignedIn:          return "Not signed in"
            case .http(let s, let b):   return "Case API HTTP \(s): \(b)"
            case .decode(let m):        return "Case API decode: \(m)"
            }
        }
    }
}
