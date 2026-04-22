// BikeLanes/Services/DenverAPI/DenverAPIClient.swift
import Foundation

/// Protocol seam for case submission; lets view-models be tested with fakes.
protocol CaseSubmitting: Sendable {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data) async throws -> AttachmentResponse
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse
}

/// Protocol seam for menu + question metadata fetch (read-only GET, safe in dry-run).
protocol MenuProviding: Sendable {
    func fetchMenus() async throws -> [DenverMenu]
    func fetchMenuQuestions(menuId: Int) async throws -> [DenverMenuQuestion]
}

extension DenverAPIClient: CaseSubmitting {}
extension DenverAPIClient: MenuProviding {}

struct DenverAPIClient: Sendable {
    /// Async callback that yields a fresh id_token when one is available, or nil
    /// for anonymous requests. Called before every request that needs auth; the
    /// AuthService implementation handles refresh + silent SSO internally.
    typealias TokenProvider = @Sendable () async throws -> String?

    let session: URLSession
    let tokenProvider: TokenProvider?

    init(session: URLSession = .shared,
         tokenProvider: TokenProvider? = nil) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: Menus

    func fetchMenus() async throws -> [DenverMenu] {
        try await getJSON(DenverEndpoints.menus)
    }

    func fetchMenuQuestions(menuId: Int) async throws -> [DenverMenuQuestion] {
        try await getJSON(DenverEndpoints.menuQuestions(menuId: menuId))
    }

    // MARK: Address search

    func searchAddress(_ query: String) async throws -> [DenverAddress.SearchResult] {
        var req = URLRequest(url: DenverEndpoints.addressSearch(query))
        await addDefaultHeaders(&req)
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status == 204 { return [] }
        guard (200...299).contains(status) else { throw APIError.http(status: status, body: data) }
        return try decoder.decode([DenverAddress.SearchResult].self, from: data)
    }

    // MARK: Attachment upload

    func uploadAttachment(id: UUID, filename: String, mimeType: String,
                          data fileData: Data) async throws -> AttachmentResponse {
        var req = URLRequest(url: DenverEndpoints.attachment(id))
        req.httpMethod = "POST"
        let boundary = Multipart.newBoundary()
        req.setValue(Multipart.contentType(boundary: boundary), forHTTPHeaderField: "Content-Type")
        await addDefaultHeaders(&req)
        // Multipart.contentType prepends "----" to the header boundary; Multipart.body expects
        // that already-prefixed value so its "--" delimiter matches RFC 2046. Pass "----" + boundary.
        req.httpBody = Multipart.body(boundary: "----" + boundary, fileField: "file",
                                      filename: filename, mimeType: mimeType, data: fileData)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    // MARK: Case create

    func createCase(_ request: CreateCaseRequest) async throws -> CreateCaseResponse {
        var req = URLRequest(url: DenverEndpoints.cases)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await addDefaultHeaders(&req)
        req.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    // MARK: Helpers

    private func addDefaultHeaders(_ req: inout URLRequest) async {
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        // Echo the SPA Origin so Denver's anti-abuse checks don't flag us.
        req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
        req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
        if let provider = tokenProvider, let token = try? await provider(), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        await addDefaultHeaders(&req)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    private func decodeOrThrow<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else { throw APIError.http(status: status, body: data) }
        return try decoder.decode(T.self, from: data)
    }

    enum APIError: Error, CustomStringConvertible {
        case http(status: Int, body: Data)

        var description: String {
            switch self {
            case .http(let s, let b):
                return "Denver API HTTP \(s): \(String(data: b, encoding: .utf8) ?? "<non-utf8>")"
            }
        }
    }
}
