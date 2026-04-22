// BikeLanes/Services/Auth/TokenStore.swift
import Foundation
import Security

/// A set of tokens + derived expiry stored as one JSON blob in the Keychain.
struct AuthTokens: Codable, Sendable {
    let idToken: String
    let refreshToken: String
    /// Absolute expiration of the id_token (from the `exp` JWT claim).
    let idTokenExpiresAt: Date
    /// Best-effort expiration of the refresh_token; server reports `refresh_token_expires_in`
    /// at issuance but rotates the token on each refresh.
    let refreshTokenExpiresAt: Date

    var idTokenIsValid: Bool { idTokenExpiresAt.timeIntervalSinceNow > 60 }
    var refreshTokenIsValid: Bool { refreshTokenExpiresAt > .now }
}

/// Keychain-backed persistence for Denver auth tokens. Uses a single generic-password
/// item keyed by `(service, account)`. The payload is a JSON-encoded `AuthTokens`.
struct TokenStore: Sendable {
    private let service: String
    private let account: String

    init(service: String = "ink.sam.bikelanes.auth",
         account: String = "denver-pocketgov") {
        self.service = service
        self.account = account
    }

    func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        // Update if present, otherwise add.
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { a, _ in a }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.osStatus(addStatus) }
        } else {
            guard updateStatus == errSecSuccess else { throw KeychainError.osStatus(updateStatus) }
        }
    }

    func load() -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error, CustomStringConvertible {
        case osStatus(OSStatus)
        var description: String {
            switch self { case .osStatus(let s): return "Keychain OSStatus \(s)" }
        }
    }
}

/// Minimal JWT claim extraction for reading `exp` and `sub` from the id_token.
/// We do NOT verify the signature here — we trust the issuer because we just
/// received it over TLS from the authorize/token endpoints. Signature checking
/// would require the JWKS and is overkill for an on-device client that never
/// forwards the token to another party.
enum JWT {
    struct Claims: Decodable {
        let exp: TimeInterval
        let sub: String?
        let iat: TimeInterval?
    }

    static func claims(of token: String) -> Claims? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        guard let payload = base64urlDecode(String(parts[1])) else { return nil }
        return try? JSONDecoder().decode(Claims.self, from: payload)
    }

    private static func base64urlDecode(_ s: String) -> Data? {
        var padded = s.replacingOccurrences(of: "-", with: "+")
                       .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }
}
