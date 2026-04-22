// BikeLanes/Services/BLU/BLUAuthService.swift
import Foundation
import Observation

/// Owner of the user's Bike Lane Uprising session. Mirrors the shape of
/// Denver's `AuthService` so SwiftUI views that drive both auth flows feel
/// symmetrical, but the implementations share no code. BLU has no OAuth,
/// no refresh tokens, no silent SSO — just a Cognito id_token obtained by
/// posting email+password to a Wix Velo endpoint.
///
/// Persistence: both the credentials AND the id_token live in the Keychain
/// (`BLUCredentialStore`), keyed separately from Denver's tokens. Session
/// tokens (wixcode-pub instance, XSRF, media upload JWT) are *not*
/// persisted — they're cheap to re-fetch from `/_api/v1/access-tokens`
/// and they expire in ~24h anyway.
@MainActor
@Observable
final class BLUAuthService {
    /// Email of the signed-in BLU user; nil when signed out. UI uses this
    /// for the "Signed in as <email>" label.
    private(set) var email: String?

    /// True whenever we hold credentials that can sign us in. The
    /// id_token may be expired — `currentIdToken()` will silently re-login
    /// using the stored password when needed.
    var isSignedIn: Bool { email != nil }

    /// Surfaced for UI spinners.
    private(set) var isAuthenticating: Bool = false

    /// In-memory snapshot of the most recent session tokens (wixcode-pub,
    /// xsrf, mediaAuth). We refetch whenever they're stale or a Velo call
    /// rejects them.
    private var tokens: BLU.SessionTokens?

    private let store: BLUCredentialStore
    private let client: BLUAPIClient

    /// Deduplicates concurrent sign-in attempts (e.g. two queued report
    /// submits both triggering a silent re-login at once).
    private var loginTask: Task<String, Error>?

    init(store: BLUCredentialStore = BLUCredentialStore(),
         client: BLUAPIClient = BLUAPIClient()) {
        self.store = store
        self.client = client
        // Peek Keychain synchronously so `isSignedIn` is correct on first
        // render. id_token freshness doesn't matter here — the actual
        // submit path will refresh if needed.
        self.email = store.load()?.email
    }

    // MARK: - Interactive sign-in

    /// Called from the BLU sign-in sheet. Bootstraps session tokens, calls
    /// `login.jsw/login.ajax`, persists the id_token + credentials on success.
    /// Throws on network error or bad credentials — the UI should surface
    /// the thrown error's `description`.
    func signIn(email: String, password: String) async throws {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let tokens = try await client.fetchSessionTokens()
        let idToken = try await client.login(tokens: tokens, email: email, password: password)
        let expiresAt = BLUAuthService.idTokenExpiry(from: idToken)

        let creds = BLUCredentials(
            email: email, password: password,
            idToken: idToken, idTokenExpiresAt: expiresAt)
        try store.save(creds)
        self.tokens = tokens
        self.email = email
    }

    /// Wipes BLU credentials + in-memory tokens. Idempotent — fine to call
    /// when already signed out.
    func signOut() {
        store.delete()
        email = nil
        tokens = nil
    }

    // MARK: - Use by the submit path

    /// Returns a fresh `(tokens, idToken)` pair ready to use in a BLU report
    /// submission. Throws if signed-out (caller should never have called us)
    /// or if silent re-login fails (network down, or the stored password
    /// has been changed elsewhere — latter requires interactive sign-in).
    func tokensForSubmit() async throws -> (BLU.SessionTokens, String) {
        guard var creds = store.load()
        else { throw BLUAuthError.notSignedIn }

        // Ensure session tokens (wixcode-pub/xsrf/mediaAuth) are fresh.
        if tokens == nil || tokens?.isFresh != true {
            tokens = try await client.fetchSessionTokens()
        }

        // Ensure the Cognito id_token is fresh; silently re-login if not.
        if !creds.idTokenIsFresh {
            let newToken = try await silentLogin(email: creds.email, password: creds.password)
            creds.idToken = newToken
            creds.idTokenExpiresAt = BLUAuthService.idTokenExpiry(from: newToken)
            try? store.save(creds)
        }

        return (tokens!, creds.idToken)
    }

    /// Re-login with stored credentials. Deduplicated so multiple queued
    /// submits don't each fire their own POST.
    private func silentLogin(email: String, password: String) async throws -> String {
        if let task = loginTask { return try await task.value }
        let task = Task<String, Error> { [client] in
            defer { self.loginTask = nil }
            let t = try await client.fetchSessionTokens()
            self.tokens = t
            return try await client.login(tokens: t, email: email, password: password)
        }
        loginTask = task
        return try await task.value
    }

    // MARK: - Helpers

    /// Decode the id_token's `exp` claim. Falls back to +23h if the JWT is
    /// unparseable (Cognito tokens are always parseable, so this is purely
    /// defensive).
    private static func idTokenExpiry(from jwt: String) -> Date {
        if let claims = JWT.claims(of: jwt) {
            return Date(timeIntervalSince1970: claims.exp)
        }
        return .now.addingTimeInterval(23 * 3600)
    }

    enum BLUAuthError: Error, CustomStringConvertible {
        case notSignedIn

        var description: String {
            switch self {
            case .notSignedIn: return "Not signed in to Bike Lane Uprising"
            }
        }
    }
}
