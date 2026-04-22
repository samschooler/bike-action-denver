// BikeLanes/Services/Auth/PKCE.swift
import Foundation
import CryptoKit

/// RFC 7636 PKCE pair + random state/nonce helpers.
enum PKCE {
    struct Pair {
        let verifier: String        // 43–128 chars, kept secret
        let challenge: String       // SHA256(verifier), base64url-encoded
        let method: String = "S256"
    }

    /// Generate a new verifier + S256 challenge pair.
    static func generate() -> Pair {
        let verifier = base64URL(Data.random(byteCount: 32))
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = base64URL(Data(digest))
        return Pair(verifier: verifier, challenge: challenge)
    }

    /// URL-safe random token for OAuth `state` / `nonce` parameters.
    static func randomToken(byteCount: Int = 24) -> String {
        base64URL(Data.random(byteCount: byteCount))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension Data {
    static func random(byteCount: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }
}
