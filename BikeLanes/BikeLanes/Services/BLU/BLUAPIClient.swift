// BikeLanes/Services/BLU/BLUAPIClient.swift
import Foundation

/// Pure stateless client for Bike Lane Uprising's Wix Velo RPC backend and
/// the Wix Media Platform. Holds no session state itself — callers pass in
/// the `BLU.SessionTokens` they got from `fetchSessionTokens()` (or had
/// cached). Token freshness + refresh is `BLUAuthService`'s job.
struct BLUAPIClient: Sendable {

    /// appDefId of Wix Code (Velo) in every Wix site. The access-tokens
    /// response keys its `apps` dict by this id; the value's `.instance`
    /// field is the `wixcode-pub.*` bearer we need for every Velo call.
    static let wixCodeAppDefId = "675bbcef-18d8-41f5-800e-131ec9e08762"
    /// Velo code bundle PK for BLU. Stable across deploys unless the site
    /// owner re-publishes Velo code — if that happens we'll start getting
    /// 404s on the dispatcher and need to re-scrape the HTML.
    static let gridAppId = "02e272fc-2755-4b7e-86e7-a1e9ce67870d"
    static let siteOrigin = "https://www.bikelaneuprising.com"

    let session: URLSession

    /// Uses an ephemeral session with its own in-memory cookie store so
    /// BLU's cookies (svSession, XSRF-TOKEN, bSession) don't bleed into —
    /// or get mixed with — Denver's URLSession.shared cookies.
    ///
    /// `.ephemeral` already gives us an isolated in-memory HTTPCookieStorage
    /// that isn't shared with `.shared`. Crucially we do NOT try to replace
    /// it with `HTTPCookieStorage()` — that initializer is not supported
    /// (Apple docs say to only use `.shared` / group-container variants),
    /// and doing so causes cookies to never be persisted or sent back on
    /// subsequent requests, which breaks the Wix double-submit CSRF check.
    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.httpCookieAcceptPolicy = .always
            cfg.httpShouldSetCookies = true
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - 1. Session tokens bootstrap

    /// Hits `/_api/v1/access-tokens` — Thunderbolt's "hand me the tokens my
    /// page would normally get at load time" endpoint. Returns the wixcode-pub
    /// instance token, the mediaAuthToken, and reads the XSRF-TOKEN cookie
    /// that the response sets on our cookie store.
    func fetchSessionTokens() async throws -> BLU.SessionTokens {
        var req = URLRequest(url: URL(string: "\(Self.siteOrigin)/_api/v1/access-tokens")!)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.siteOrigin, forHTTPHeaderField: "Origin")
        req.setValue("\(Self.siteOrigin)/submit", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: req)
        try Self.requireHTTPSuccess(response, data: data)

        struct Wire: Decodable {
            let mediaAuthToken: String
            let apps: [String: AppEntry]
            struct AppEntry: Decodable { let instance: String? }
        }
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        guard let wcApp = wire.apps[Self.wixCodeAppDefId],
              let pubToken = wcApp.instance, !pubToken.isEmpty
        else { throw BLUError.missingWixCodeAppInstance }

        // Pull XSRF-TOKEN from the response's Set-Cookie headers directly.
        // We used to read from `session.configuration.httpCookieStorage`,
        // but that returns a snapshot from the configuration — not the
        // session's live cookie store — so it was empty at read time.
        // Parsing Set-Cookie off the HTTPURLResponse is reliable regardless
        // of which cookie storage the URLSession ended up using.
        let xsrfValue = Self.extractXSRF(from: response, requestURL: req.url!)
        guard let xsrfValue, !xsrfValue.isEmpty
        else { throw BLUError.missingXsrfCookie }

        return BLU.SessionTokens(
            wixcodePubToken: pubToken,
            xsrfToken: xsrfValue,
            mediaAuthToken: wire.mediaAuthToken,
            capturedAt: .now)
    }

    // MARK: - 2. Login / session-valid

    /// `POST login.jsw/login.ajax` with positional body `[email, password]`.
    /// Returns the AWS Cognito id_token on success. Throws `.loginRejected`
    /// if `approved == false` or the response shape is unexpected.
    func login(tokens: BLU.SessionTokens, email: String, password: String) async throws -> String {
        let body = try JSONEncoder().encode(BLU.LoginArgs(email: email, password: password))
        let data = try await veloPOST(
            path: "backend/login/login.jsw/login.ajax",
            body: body, tokens: tokens)
        let wrapped = try JSONDecoder().decode(BLU.LoginResponse.self, from: data)
        guard wrapped.result.approved, let token = wrapped.result.token
        else { throw BLUError.loginRejected }
        return token
    }

    /// `POST submit.jsw/userSessionIsValid.ajax [idToken]` — used to probe
    /// whether a stored Cognito id_token is still accepted by BLU's backend
    /// without re-entering credentials.
    func isSessionValid(tokens: BLU.SessionTokens, idToken: String) async throws -> Bool {
        let body = try JSONEncoder().encode(BLU.SessionValidArgs(idToken: idToken))
        let data = try await veloPOST(
            path: "backend/submit/submit.jsw/userSessionIsValid.ajax",
            body: body, tokens: tokens)
        return (try JSONDecoder().decode(BLU.SessionValidResponse.self, from: data)).result
    }

    // MARK: - 3. Photo upload (two-hop)

    /// End-to-end upload: request an upload URL, PUT the bytes, return the
    /// public `https://static.wixstatic.com/…` URL that `submit.ajax`
    /// should reference in `images`.
    func uploadPhoto(
        tokens: BLU.SessionTokens,
        data fileData: Data,
        filename: String,
        mimeType: String
    ) async throws -> String {
        // Hop A: request one-shot upload URL.
        var urlComp = URLComponents(string: "https://files.wix.com/site/media/files/upload/url")!
        urlComp.queryItems = [
            .init(name: "parent_folder_id", value: "visitor-uploads"),
            .init(name: "media_type", value: "picture"),
            .init(name: "file_name", value: filename),
            .init(name: "mime_type", value: mimeType),
        ]
        var reqA = URLRequest(url: urlComp.url!)
        reqA.setValue("APP \(tokens.mediaAuthToken)", forHTTPHeaderField: "Authorization")
        reqA.setValue(Self.siteOrigin, forHTTPHeaderField: "Origin")
        reqA.setValue("\(Self.siteOrigin)/submit", forHTTPHeaderField: "Referer")
        reqA.setValue("application/json", forHTTPHeaderField: "Accept")
        let (aData, aResp) = try await session.data(for: reqA)
        try Self.requireHTTPSuccess(aResp, data: aData)
        let uploadURLResp = try JSONDecoder().decode(BLU.UploadURLResponse.self, from: aData)
        guard let uploadURL = URL(string: uploadURLResp.upload_url)
        else { throw BLUError.badUploadURL }

        // Hop B: PUT the raw bytes. The JWT in the URL carries auth + bucket.
        var reqB = URLRequest(url: uploadURL)
        reqB.httpMethod = "PUT"
        reqB.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        reqB.setValue(Self.siteOrigin, forHTTPHeaderField: "Origin")
        reqB.setValue("\(Self.siteOrigin)/submit", forHTTPHeaderField: "Referer")
        reqB.httpBody = fileData
        let (bData, bResp) = try await session.data(for: reqB)
        try Self.requireHTTPSuccess(bResp, data: bData)
        let files = try JSONDecoder().decode([BLU.UploadedFile].self, from: bData)
        guard let fileURL = files.first?.file_url
        else { throw BLUError.uploadNoFileURL }

        return "https://static.wixstatic.com/\(fileURL)"
    }

    // MARK: - 4. Submit

    /// `POST submit.jsw/submit.ajax [{…body…}]`. Wix wraps the single-object
    /// argument in a one-element array (positional RPC). Success is `200 {}`.
    func submit(tokens: BLU.SessionTokens, body: BLU.SubmitBody) async throws {
        // Wrap the body in a one-element array to match Velo's positional RPC.
        let encoder = JSONEncoder()
        let inner = try encoder.encode(body)
        var wrapped = Data("[".utf8)
        wrapped.append(inner)
        wrapped.append(Data("]".utf8))
        let data = try await veloPOST(
            path: "backend/submit/submit.jsw/submit.ajax",
            body: wrapped, tokens: tokens)
        _ = try JSONDecoder().decode(BLU.SubmitResponse.self, from: data)
    }

    // MARK: - Shared Velo POST

    /// Every Velo web-method call goes through the same dispatcher path
    /// and shares the same auth/header set. `path` is the tail after
    /// `…_webMethods/`, e.g. `backend/submit/submit.jsw/submit.ajax`.
    private func veloPOST(path: String, body: Data, tokens: BLU.SessionTokens) async throws -> Data {
        var comp = URLComponents(string: "\(Self.siteOrigin)/_api/wix-code-public-dispatcher-ng/siteview/_webMethods/\(path)")!
        comp.queryItems = [
            .init(name: "gridAppId", value: Self.gridAppId),
            .init(name: "viewMode", value: "site"),
        ]
        var req = URLRequest(url: comp.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(tokens.wixcodePubToken, forHTTPHeaderField: "Authorization")
        req.setValue(tokens.wixcodePubToken, forHTTPHeaderField: "x-wix-app-instance")
        req.setValue(tokens.xsrfToken, forHTTPHeaderField: "x-xsrf-token")
        req.setValue("wix", forHTTPHeaderField: "x-wix-brand")
        req.setValue(Self.siteOrigin, forHTTPHeaderField: "Origin")
        req.setValue("\(Self.siteOrigin)/submit", forHTTPHeaderField: "Referer")
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        try Self.requireHTTPSuccess(response, data: data)
        return data
    }

    // MARK: - Errors

    enum BLUError: Error, CustomStringConvertible {
        case httpError(status: Int, body: String)
        case missingWixCodeAppInstance
        case missingXsrfCookie
        case loginRejected
        case badUploadURL
        case uploadNoFileURL

        var description: String {
            switch self {
            case .httpError(let s, let b):       return "BLU HTTP \(s): \(b)"
            case .missingWixCodeAppInstance:     return "access-tokens response had no Wix Code app instance"
            case .missingXsrfCookie:             return "access-tokens response did not set XSRF-TOKEN cookie"
            case .loginRejected:                 return "BLU login rejected (bad credentials or account issue)"
            case .badUploadURL:                  return "Wix upload URL response malformed"
            case .uploadNoFileURL:               return "Wix upload succeeded but returned no file_url"
            }
        }
    }

    /// Parse the XSRF-TOKEN value out of the response's Set-Cookie headers.
    /// Uses Foundation's RFC-6265 cookie parser rather than a regex on the
    /// raw header, so quoted values / attributes don't trip us up.
    private static func extractXSRF(from response: URLResponse, requestURL: URL) -> String? {
        guard let http = response as? HTTPURLResponse else { return nil }
        let fields = http.allHeaderFields
            .reduce(into: [String: String]()) { acc, pair in
                if let k = pair.key as? String { acc[k] = "\(pair.value)" }
            }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: requestURL)
        return cookies.first(where: { $0.name == "XSRF-TOKEN" })?.value
    }

    private static func requireHTTPSuccess(_ response: URLResponse, data: Data) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw BLUError.httpError(status: status, body: body)
        }
    }
}
