// BikeLanes/Views/Auth/LoginSheet.swift
import SwiftUI

/// Sheet that presents Azure B2C sign-in. Holds the PKCE pair so the auth-code
/// returned from the WebView can be exchanged for tokens.
struct LoginSheet: View {
    let auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var pkce: PKCE.Pair = PKCE.generate()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LoginWebView(
                    initialURL: auth.authorizeURL(prompt: "login", pkce: pkce),
                    onCode: { code in
                        Task {
                            do {
                                try await auth.completeSignIn(code: code, pkce: pkce)
                                dismiss()
                            } catch {
                                errorMessage = String(describing: error)
                            }
                        }
                    },
                    onError: { err in
                        errorMessage = String(describing: err)
                    })
                if let errorMessage {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 179/255, green: 58/255, blue: 58/255))
                    }
                }
                if auth.isAuthenticating {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Signing in…").tint(.white).foregroundStyle(.white)
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
