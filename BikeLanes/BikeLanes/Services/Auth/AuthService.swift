// BikeLanes/Services/Auth/AuthService.swift
import Foundation
import Observation
import WebKit

/// Orchestrates Azure B2C sign-in/sign-out and keeps the user's tokens + profile
/// in sync. Exposes an async `currentIdToken()` that's safe to call before every
/// API request: it preemptively refreshes when the id_token is near expiry, and
/// attempts silent SSO (via the persistent B2C cookie) if the refresh token itself
/// has expired. The caller never has to know which path produced the bearer.
@MainActor
@Observable
final class AuthService {
    /// nil when signed out; populated as soon as we have valid tokens + a profile.
    var profile: UserProfile?
    /// Optimistic "signed in" signal — `true` as soon as we have tokens in the
    /// Keychain, even before the profile fetch completes. Flips to `false` when
    /// we sign out or an API call surfaces that the account was invalidated.
    var hasCredentials: Bool

    /// True when signed in via the hardcoded demo account used by the App Store
    /// review team. In this mode we never touch the real Denver API — submits
    /// are synthetic, history is a canned fixture — so reviewers can exercise
    /// the full flow without filing real 311 cases.
    var isDemoMode: Bool = false
    /// True when either profile is loaded OR we have tokens and will soon load one.
    var isSignedIn: Bool { profile != nil || hasCredentials }
    /// Surfaced for UI ("Signing in…" states).
    var isAuthenticating: Bool = false

    private let store: TokenStore
    private let session: URLSession
    /// Cookies live here so "silent SSO" can work after the refresh token expires.
    private let dataStore: WKWebsiteDataStore = .default()
    private var refreshTask: Task<String, Error>?

    init(store: TokenStore = TokenStore(), session: URLSession = .shared) {
        self.store = store
        self.session = session
        // Peek the Keychain synchronously so the UI can skip the sign-in prompt
        // immediately on launch if tokens exist. Profile loads async afterwards.
        self.hasCredentials = (store.load()?.refreshTokenIsValid == true)
    }

    /// Enter demo mode — synthesises a signed-in state without contacting any
    /// real auth backend. Every subsequent submit / history fetch is faked
    /// (see `ReportViewModel.submit()` and `HistoryViewModel.refresh()`).
    /// Used by App Store reviewers and anyone who wants to see the flow
    /// without a Denver PocketGov account.
    func enterDemoMode() {
        self.profile = UserProfile(
            id: "demo-apple-reviewer",
            firstName: "Apple",
            lastName: "Reviewer",
            displayName: "Apple Reviewer",
            email: "demo@sam.ink",
            phone: nil,
            preferredLanguage: "en")
        self.hasCredentials = true
        self.isDemoMode = true
    }

    /// Call when an API response indicates the user is no longer authenticated
    /// (401 Unauthorized on an endpoint that needs auth, refresh token rejected,
    /// Keychain wiped, etc.). Drops local tokens so the UI flips back to the
    /// sign-in prompt on the next render.
    func invalidate() {
        store.delete()
        profile = nil
        hasCredentials = false
    }

    /// Called once at app start. Rehydrates the profile if a usable token already
    /// exists; otherwise leaves us signed out.
    func restore() async {
        guard let tokens = store.load() else { return }
        if tokens.idTokenIsValid {
            await fetchProfileIfNeeded(using: tokens.idToken)
            return
        }
        if tokens.refreshTokenIsValid {
            _ = try? await refresh(using: tokens.refreshToken)
            return
        }
        // Both tokens expired. Try silent SSO against the B2C cookie.
        _ = try? await silentReauthorize()
    }

    /// Returns a valid id_token, refreshing or silently re-authorizing as needed.
    /// nil means we have no way to get one (user is signed out, no B2C cookie).
    /// **Demo mode short-circuits to nil** — even if something somehow called
    /// an authenticated Denver endpoint while in demo mode, we would never
    /// attach a Bearer token or trigger a B2C refresh.
    func currentIdToken() async throws -> String? {
        if isDemoMode { return nil }
        if let tokens = store.load() {
            if tokens.idTokenIsValid { return tokens.idToken }
            if tokens.refreshTokenIsValid { return try await refresh(using: tokens.refreshToken) }
        }
        return try? await silentReauthorize()
    }

    /// Called from LoginWebView when it has intercepted the redirect URI and extracted
    /// the auth code. Exchanges it for tokens and populates `profile`.
    func completeSignIn(code: String, pkce: PKCE.Pair) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let tokens = try await exchangeCodeForTokens(code: code, verifier: pkce.verifier)
        try store.save(tokens)
        hasCredentials = true
        await fetchProfileIfNeeded(using: tokens.idToken)
    }

    /// Wipe tokens, profile, and B2C cookies so the user actually has to type
    /// credentials again next time.
    func signOut() async {
        store.delete()
        profile = nil
        hasCredentials = false
        isDemoMode = false
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        await dataStore.removeData(ofTypes: allTypes, modifiedSince: .distantPast)
    }

    // MARK: - Refresh

    /// Deduplicates concurrent refresh attempts — if two requests hit a near-expiry
    /// token at once we'd otherwise issue two refresh POSTs and race each other.
    private func refresh(using refreshToken: String) async throws -> String {
        if let task = refreshTask { return try await task.value }
        let task = Task<String, Error> {
            defer { self.refreshTask = nil }
            let tokens = try await exchangeRefreshToken(refreshToken)
            try store.save(tokens)
            if profile == nil {
                await fetchProfileIfNeeded(using: tokens.idToken)
            }
            return tokens.idToken
        }
        refreshTask = task
        return try await task.value
    }

    // MARK: - Token exchange primitives

    private func exchangeCodeForTokens(code: String, verifier: String) async throws -> AuthTokens {
        let body = [
            "client_id": AuthConstants.clientId,
            "grant_type": "authorization_code",
            "redirect_uri": AuthConstants.redirect,
            "scope": AuthConstants.scope,
            "code": code,
            "code_verifier": verifier,
            "client_info": "1",
        ]
        return try await postForm(body)
    }

    private func exchangeRefreshToken(_ refreshToken: String) async throws -> AuthTokens {
        let body = [
            "client_id": AuthConstants.clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": AuthConstants.scope,
            "client_info": "1",
        ]
        return try await postForm(body)
    }

    private func postForm(_ params: [String: String]) async throws -> AuthTokens {
        var req = URLRequest(url: AuthConstants.token)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v)"
        }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            throw AuthError.tokenHTTP(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return try decode(tokenResponse: data)
    }

    private func decode(tokenResponse data: Data) throws -> AuthTokens {
        struct Wire: Decodable {
            let id_token: String
            let refresh_token: String?
            let refresh_token_expires_in: Double?
            // `expires_in` for the access_token is irrelevant — we use id_token lifetime.
        }
        let wire = try JSONDecoder().decode(Wire.self, from: data)
        // Trust the id_token's own `exp` claim; fall back to +1h if it's not parseable.
        let idExp: Date = {
            if let c = JWT.claims(of: wire.id_token) { return Date(timeIntervalSince1970: c.exp) }
            return .now.addingTimeInterval(3600)
        }()
        // Refresh tokens rotate on each refresh — use whatever expiry the server returns.
        let refreshExp = Date.now.addingTimeInterval(wire.refresh_token_expires_in ?? 86_400)
        // Azure B2C issues a NEW refresh token on every refresh call — we plumb it back in.
        let newRefresh = wire.refresh_token ?? store.load()?.refreshToken ?? ""
        guard !newRefresh.isEmpty else { throw AuthError.missingRefreshToken }
        return AuthTokens(
            idToken: wire.id_token,
            refreshToken: newRefresh,
            idTokenExpiresAt: idExp,
            refreshTokenExpiresAt: refreshExp)
    }

    // MARK: - Silent SSO

    /// Loads /authorize with `prompt=none` in an OFF-SCREEN WKWebView. If the B2C
    /// session cookie is still valid (usually 7–30 days), B2C redirects to our
    /// callback with an auth code — no UI, no user interaction. If the cookie is
    /// gone or invalid, the server returns an `interaction_required` error instead;
    /// we surface that as `AuthError.needsInteractive` so the caller knows to
    /// prompt the user.
    private func silentReauthorize() async throws -> String {
        let pkce = PKCE.generate()
        let url = authorizeURL(prompt: "none", pkce: pkce)
        let code = try await SilentAuthRunner.run(url: url, dataStore: dataStore)
        let tokens = try await exchangeCodeForTokens(code: code, verifier: pkce.verifier)
        try store.save(tokens)
        if profile == nil { await fetchProfileIfNeeded(using: tokens.idToken) }
        return tokens.idToken
    }

    /// Builds an /authorize URL; `prompt` is "login" for interactive, "none" for silent.
    /// `response_mode=query` is essential: MSAL defaults to `fragment` for SPAs, but
    /// WKWebView's navigation delegate doesn't always fire for fragment-only changes,
    /// and Denver's global-auth-handler SPA would render its error page before we
    /// could intercept. Query mode makes the `?code=…` visible to decidePolicyFor.
    func authorizeURL(prompt: String = "login", pkce: PKCE.Pair) -> URL {
        var comps = URLComponents(url: AuthConstants.authorize, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "client_id", value: AuthConstants.clientId),
            .init(name: "redirect_uri", value: AuthConstants.redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "response_mode", value: "query"),
            .init(name: "scope", value: AuthConstants.scope),
            .init(name: "code_challenge", value: pkce.challenge),
            .init(name: "code_challenge_method", value: pkce.method),
            .init(name: "state", value: PKCE.randomToken()),
            .init(name: "nonce", value: PKCE.randomToken()),
            .init(name: "prompt", value: prompt),
            .init(name: "client_info", value: "1"),
        ]
        return comps.url!
    }

    // MARK: - Profile

    private func fetchProfileIfNeeded(using idToken: String) async {
        do {
            self.profile = try await ProfileService().fetch(idToken: idToken)
        } catch {
            // Leave profile nil; next API call will retry via currentIdToken().
        }
    }

    enum AuthError: Error, CustomStringConvertible {
        case tokenHTTP(status: Int, body: String)
        case missingRefreshToken
        case needsInteractive
        case redirectMissingCode

        var description: String {
            switch self {
            case .tokenHTTP(let s, let b): return "Token endpoint HTTP \(s): \(b)"
            case .missingRefreshToken:     return "Token response had no refresh_token"
            case .needsInteractive:        return "Silent SSO requires the user to re-enter credentials"
            case .redirectMissingCode:     return "Authorize redirect did not include a code"
            }
        }
    }
}
