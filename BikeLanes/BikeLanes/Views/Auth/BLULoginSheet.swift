// BikeLanes/Views/Auth/BLULoginSheet.swift
import SwiftUI

/// Native email+password form for signing into Bike Lane Uprising.
/// Unlike Denver's PocketGov flow there's no OAuth / redirect to intercept —
/// BLU's Wix Velo endpoint accepts `login.ajax([email, password])` directly —
/// so a native form is cleaner than embedding a WebView.
struct BLULoginSheet: View {
    let blu: BLUAuthService
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @FocusState private var passwordFocused: Bool

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !blu.isAuthenticating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { passwordFocused = true }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($passwordFocused)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { submit() } }
                } footer: {
                    Text("These credentials are stored in the iOS Keychain on this device and are used only to sign in to bikelaneuprising.com.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if blu.isAuthenticating {
                                ProgressView()
                            } else {
                                Text("Sign in")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Bike Lane Uprising")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil
        Task {
            do {
                try await blu.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                     password: password)
                dismiss()
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}
