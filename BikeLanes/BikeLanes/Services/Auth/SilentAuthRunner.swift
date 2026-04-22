// BikeLanes/Services/Auth/SilentAuthRunner.swift
import Foundation
import WebKit

/// Drives a hidden WKWebView through the /authorize endpoint with `prompt=none`.
/// If the persisted B2C session cookie is still valid the endpoint redirects
/// to our callback URL with `?code=…` (or `#code=…`); we extract it and resolve.
/// Any "interaction_required" redirect yields `AuthService.AuthError.needsInteractive`.
@MainActor
enum SilentAuthRunner {
    static func run(url: URL, dataStore: WKWebsiteDataStore) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let box = Box(continuation: continuation)
            let config = WKWebViewConfiguration()
            config.websiteDataStore = dataStore
            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isHidden = true
            let delegate = SilentDelegate(box: box, webView: webView)
            webView.navigationDelegate = delegate
            // Retain the delegate for the lifetime of the continuation.
            box.delegate = delegate
            webView.load(URLRequest(url: url))
        }
    }

    /// Single-shot callback holder. Uses a class reference so the WKNavigationDelegate
    /// can resolve exactly one completion and ignore subsequent navigation events.
    final class Box {
        var continuation: CheckedContinuation<String, Error>?
        var delegate: SilentDelegate?
        init(continuation: CheckedContinuation<String, Error>) {
            self.continuation = continuation
        }
        func resume(_ result: Result<String, Error>) {
            guard let cc = continuation else { return }
            continuation = nil
            delegate = nil
            switch result {
            case .success(let code): cc.resume(returning: code)
            case .failure(let err):  cc.resume(throwing: err)
            }
        }
    }

    final class SilentDelegate: NSObject, WKNavigationDelegate {
        let box: Box
        weak var webView: WKWebView?
        init(box: Box, webView: WKWebView) { self.box = box; self.webView = webView }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let outcome = OAuthRedirect.classify(navigationAction.request.url) {
                decisionHandler(.cancel)
                box.resume(outcome.toResult())
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            box.resume(.failure(error))
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            box.resume(.failure(error))
        }
    }
}

/// Shared redirect-URL classifier. Used by both the silent runner and the interactive
/// login WebView so they interpret the callback identically.
enum OAuthRedirect {
    enum Outcome {
        case code(String)
        case interactionRequired
        case error(String)

        func toResult() -> Result<String, Error> {
            switch self {
            case .code(let c):           return .success(c)
            case .interactionRequired:   return .failure(AuthService.AuthError.needsInteractive)
            case .error(let e):          return .failure(AuthService.AuthError.tokenHTTP(status: -1, body: e))
            }
        }
    }

    /// Returns non-nil when the URL is our redirect URI (with either a `code` or an error).
    /// Matches by host + path rather than raw-string prefix so we're tolerant of
    /// casing differences, query-param ordering, or the trailing-slash toggle.
    static func classify(_ url: URL?) -> Outcome? {
        guard let url else { return nil }
        guard let expected = URLComponents(string: AuthConstants.redirect),
              let actual = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let sameHost = (actual.host?.lowercased() == expected.host?.lowercased())
        let actualPath = actual.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let expectedPath = expected.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let samePath = actualPath.caseInsensitiveCompare(expectedPath) == .orderedSame
        guard sameHost, samePath else { return nil }

        // Params can arrive in query OR fragment depending on response_mode. Try both.
        let queryItems = actual.queryItems ?? []
        let fragmentItems: [URLQueryItem] = url.fragment.flatMap { frag in
            URLComponents(string: "?\(frag)")?.queryItems
        } ?? []
        let all = queryItems + fragmentItems
        if let code = all.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return .code(code)
        }
        if let err = all.first(where: { $0.name == "error" })?.value {
            if err.contains("interaction_required") || err.contains("login_required")
                || err.contains("consent_required") {
                return .interactionRequired
            }
            let desc = all.first(where: { $0.name == "error_description" })?.value ?? err
            return .error(desc)
        }
        return nil
    }
}
