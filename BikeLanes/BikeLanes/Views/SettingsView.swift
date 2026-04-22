// BikeLanes/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var showingLogin = false
    let auth: AuthService?

    init(auth: AuthService? = nil) {
        self.auth = auth
    }

    var body: some View {
        Form {
            Section("Account") {
                if let auth {
                    if auth.isDemoMode {
                        LabeledContent("Signed in as", value: "Demo Mode")
                        Text("Submissions and history are simulated. Nothing is sent to Denver 311.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Exit demo mode", role: .destructive) {
                            Task { await auth.signOut() }
                        }
                    } else if let profile = auth.profile {
                        LabeledContent("Signed in as", value: profile.displayLabel)
                        if let email = profile.email, !email.isEmpty {
                            LabeledContent("Email", value: email)
                        }
                        Button("Sign out", role: .destructive) {
                            Task { await auth.signOut() }
                        }
                    } else if auth.hasCredentials {
                        LabeledContent("Signed in", value: "loading profile…")
                        Button("Sign out", role: .destructive) {
                            Task { await auth.signOut() }
                        }
                    } else {
                        Button("Sign in with Denver PocketGov") { showingLogin = true }
                        Text("Signing in lets Denver tie reports to your account so you can see status updates. Required to file a report.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Try Demo Mode") {
                            auth.enterDemoMode()
                        }
                        Text("Exercises the full flow without a Denver account. Submissions and history are simulated — nothing is sent to Denver 311.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Auth unavailable in this build.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersion ?? "?")
                Link(destination: URL(string: "https://github.com/samschooler/bike-action-denver")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text("Source on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
                Link("Privacy policy", destination: URL(string: "https://sam.ink/bike-action-denver/privacy/")!)
            }
            Section("What this does") {
                Text("Submits illegal-parking reports to Denver's 311 system. All photo analysis happens on your device; the photo and address are uploaded to Denver.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingLogin) {
            if let auth { LoginSheet(auth: auth) }
        }
    }
}

private extension Bundle {
    var shortVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
