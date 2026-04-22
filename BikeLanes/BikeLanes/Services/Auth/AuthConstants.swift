// BikeLanes/Services/Auth/AuthConstants.swift
import Foundation

/// Azure AD B2C endpoints + constants for Denver's PocketGov SPA, lifted from
/// the reverse-engineered HAR (see data/API.md § 2). We reuse the SPA's own
/// client_id because Denver doesn't publish a native-app registration — the
/// WebView flow posts to the same `global-auth-handler` redirect the web app
/// uses, and we intercept the callback in-app instead of letting it navigate
/// to denvergov.org.
enum AuthConstants {
    static let tenantHost = "denverresidents.b2clogin.com"
    static let tenantId   = "d8a278b1-6e69-429a-9e51-b2ba11f5703d"
    static let policy     = "B2C_1A_DenverGov_SignUpOrSignin"
    static let clientId   = "684aed88-0697-479e-a565-f5ed62c6ea3f"
    static let redirect   = "https://www.denvergov.org/appservices/global-auth-handler/"

    /// Exact scope string MSAL.js requests. Order matters for the id_token aud/claims.
    static let scope = "https://graph.microsoft.com/User.Read https://graph.microsoft.com/Directory.Read openid profile offline_access"

    static var authorize: URL {
        URL(string: "https://\(tenantHost)/\(tenantId)/\(policy)/oauth2/v2.0/authorize")!
    }
    static var token: URL {
        URL(string: "https://\(tenantHost)/\(tenantId)/\(policy)/oauth2/v2.0/token")!
    }
    static var logout: URL {
        URL(string: "https://\(tenantHost)/\(tenantId)/\(policy)/oauth2/v2.0/logout")!
    }
}
