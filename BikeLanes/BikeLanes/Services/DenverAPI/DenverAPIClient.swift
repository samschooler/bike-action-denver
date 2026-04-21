// BikeLanes/Services/DenverAPI/DenverAPIClient.swift
import Foundation

struct DenverAPIClient: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
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
        addDefaultHeaders(&req)
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
        addDefaultHeaders(&req)
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
        addDefaultHeaders(&req)
        req.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: req)
        return try decodeOrThrow(data, response)
    }

    // MARK: Helpers

    private func addDefaultHeaders(_ req: inout URLRequest) {
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        // Echo the SPA Origin so Denver's anti-abuse checks don't flag us.
        req.setValue("https://www.denvergov.org", forHTTPHeaderField: "Origin")
        req.setValue("https://www.denvergov.org/", forHTTPHeaderField: "Referer")
    }

    private func getJSON<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        addDefaultHeaders(&req)
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
