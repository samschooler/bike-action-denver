// BikeLanes/Views/Auth/LoginWebView.swift
import SwiftUI
import WebKit

/// WKWebView that drives the Azure B2C sign-in flow. Shares its website data
/// store with `WKWebsiteDataStore.default()` so the B2C session cookie persists
/// across app launches — that's what enables silent SSO when the refresh token
/// eventually expires.
///
/// When the WebView navigates to our redirect URI, we extract the `code`
/// parameter, cancel the navigation, and hand the code to `onCode`. The caller
/// is responsible for exchanging it at the /token endpoint.
struct LoginWebView: UIViewRepresentable {
    let initialURL: URL
    let onCode: (String) -> Void
    let onError: (Error) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Belt-and-suspenders: if the decidePolicyFor hook misses a fragment-only
        // navigation (iOS WebKit has a long history of inconsistent nav events for
        // hash changes), KVO on `url` lets us spot the redirect the moment the URL
        // property updates.
        context.coordinator.observeURL(of: webView)
        webView.load(URLRequest(url: initialURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onCode: (String) -> Void
        let onError: (Error) -> Void
        private var didFinish = false
        private var urlObservation: NSKeyValueObservation?

        init(onCode: @escaping (String) -> Void,
             onError: @escaping (Error) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        deinit { urlObservation?.invalidate() }

        func observeURL(of webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
                guard let self, !self.didFinish, let url = change.newValue ?? nil else { return }
                if let outcome = OAuthRedirect.classify(url) {
                    self.didFinish = true
                    webView.stopLoading()
                    self.dispatch(outcome)
                }
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard !didFinish, let outcome = OAuthRedirect.classify(navigationAction.request.url) else {
                decisionHandler(.allow); return
            }
            didFinish = true
            decisionHandler(.cancel)
            dispatch(outcome)
        }

        private func dispatch(_ outcome: OAuthRedirect.Outcome) {
            switch outcome {
            case .code(let code): onCode(code)
            case .interactionRequired, .error:
                outcome.toResult().forErrorOnly(onError)
            }
        }
    }
}

private extension Result where Success == String {
    func forErrorOnly(_ handler: (Error) -> Void) {
        if case .failure(let err) = self { handler(err) }
    }
}
