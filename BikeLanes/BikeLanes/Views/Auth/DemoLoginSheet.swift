// BikeLanes/Views/Auth/DemoLoginSheet.swift
import SwiftUI

/// Hardcoded-credentials login for the App Store review team. Presents a
/// minimal email + password form; success flips `AuthService.isDemoMode` on
/// and every subsequent submit / history fetch is synthesized — no calls to
/// Denver's real 311 system.
///
/// Real users sign in via `LoginSheet` (Azure AD B2C in a WKWebView). This
/// sheet is a deliberately separate entry point so nobody mistakes it for
/// the real thing.
struct DemoLoginSheet: View {
    let auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String?
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .email)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focused, equals: .password)
                } header: {
                    Text("Demo credentials")
                } footer: {
                    Text("This account ships with the app so App Store reviewers can exercise the full flow. Submissions are simulated — nothing reaches Denver 311.")
                        .font(.footnote)
                }

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                }

                Section {
                    Button {
                        attemptSignIn()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign in").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Bike Action Denver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = .email }
        }
    }

    private func attemptSignIn() {
        if auth.signInAsDemo(email: email, password: password) {
            dismiss()
        } else {
            error = "Those credentials didn't match."
            password = ""
            focused = .password
        }
    }
}
