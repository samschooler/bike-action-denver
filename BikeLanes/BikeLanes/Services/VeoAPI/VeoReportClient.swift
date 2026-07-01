import Foundation

protocol VeoSubmitting: Sendable {
    func fetchCSRFToken() async throws -> String
    func uploadAttachment(filename: String, mimeType: String, data: Data) async throws -> VeoAttachment
    func submit(_ submission: VeoSubmission) async throws
}

struct VeoReportClient: VeoSubmitting {
    let session: URLSession

    init(session: URLSession = VeoReportClient.makeSession()) {
        self.session = session
    }

    /// Session with its own cookie jar so the _help_center_session cookie set by
    /// the CSRF GET is sent on the subsequent upload + submit POSTs.
    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage()
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        return URLSession(configuration: cfg)
    }

    private struct CSRFEnvelope: Decodable {
        struct Session: Decodable { let csrf_token: String }
        let current_session: Session
    }

    func fetchCSRFToken() async throws -> String {
        var req = URLRequest(url: VeoEndpoints.csrfToken)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        try Self.ensure2xx(response, data)
        return try JSONDecoder().decode(CSRFEnvelope.self, from: data).current_session.csrf_token
    }

    func uploadAttachment(filename: String, mimeType: String, data fileData: Data) async throws -> VeoAttachment {
        var req = URLRequest(url: VeoEndpoints.requestUploads)
        req.httpMethod = "POST"
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue(VeoEndpoints.base.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(VeoEndpoints.requests.absoluteString + "/new", forHTTPHeaderField: "Referer")
        let boundary = Multipart.newBoundary()
        req.setValue(Multipart.contentType(boundary: boundary), forHTTPHeaderField: "Content-Type")
        req.httpBody = Multipart.body(boundary: "----" + boundary, fileField: "file",
                                      filename: filename, mimeType: mimeType, data: fileData)
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        try Self.ensure2xx(response, data)
        var att = try JSONDecoder().decode(VeoAttachment.self, from: data)
        att.rawJSON = String(data: data, encoding: .utf8) ?? ""
        return att
    }

    func submit(_ submission: VeoSubmission) async throws {
        var req = URLRequest(url: VeoEndpoints.requests)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue(VeoEndpoints.base.absoluteString, forHTTPHeaderField: "Origin")
        req.setValue(VeoEndpoints.requests.absoluteString + "/new", forHTTPHeaderField: "Referer")
        req.httpBody = submission.formURLEncodedBody().data(using: .utf8)
        let (data, response) = try await session.data(for: req, delegate: NoRedirect())
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 302 else { throw VeoError.http(status: status, body: data) }
    }

    private static func ensure2xx(_ response: URLResponse, _ data: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else { throw VeoError.http(status: status, body: data) }
    }
}

/// Prevents URLSession from auto-following the 302 that signals a successful
/// Zendesk submit, so we can observe the redirect status directly.
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

enum VeoError: Error, CustomStringConvertible {
    case http(status: Int, body: Data)
    case badResponse
    case csrfMissing

    var description: String {
        switch self {
        case .http(let s, let b):
            return "Veo HTTP \(s): \(String(data: b, encoding: .utf8) ?? "<non-utf8>")"
        case .badResponse: return "Unexpected response from Veo."
        case .csrfMissing: return "Could not obtain a Veo session token."
        }
    }
}
