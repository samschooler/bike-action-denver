// BikeLanes/Services/BLU/BLUCredentialStore.swift
import Foundation
import Security

/// Everything we need to restore an authenticated BLU session across app
/// launches. Stored as one JSON blob in a Keychain item completely separate
/// from Denver's `TokenStore` — different service, different account, no
/// shared state.
///
/// We store the *password* alongside the id_token so we can silently
/// re-login when the id_token expires (24h) instead of forcing the user
/// back to the sign-in screen. The HAR capture showed no refresh-token
/// support on BLU's Cognito app client, so silent re-login with stored
/// credentials is the only option.
struct BLUCredentials: Codable, Sendable {
    let email: String
    let password: String
    /// Latest AWS Cognito id_token from `login.jsw/login.ajax`. Carries the
    /// user's BLU identity inside `submit.ajax`'s `cognitoToken` field.
    var idToken: String
    /// id_token `exp` claim as an absolute Date. ~24h from issue.
    var idTokenExpiresAt: Date

    var idTokenIsFresh: Bool { idTokenExpiresAt.timeIntervalSinceNow > 5 * 60 }
}

/// Keychain-backed persistence for BLU credentials. Intentionally mirrors
/// the `TokenStore` shape so anyone reading both services can recognise
/// the pattern, but the item is keyed separately so Denver's auth flow
/// can never read or overwrite BLU credentials.
struct BLUCredentialStore: Sendable {
    private let service: String
    private let account: String

    init(service: String = "ink.sam.bikelanes.blu",
         account: String = "bikelaneuprising") {
        self.service = service
        self.account = account
    }

    func save(_ creds: BLUCredentials) throws {
        let data = try JSONEncoder().encode(creds)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
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

    func load() -> BLUCredentials? {
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
        return try? JSONDecoder().decode(BLUCredentials.self, from: data)
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
            switch self { case .osStatus(let s): return "BLU keychain OSStatus \(s)" }
        }
    }
}
