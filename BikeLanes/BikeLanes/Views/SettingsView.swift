// BikeLanes/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var showingEraseConfirm = false
    let repo: CasePersisting

    init(repo: CasePersisting) { self.repo = repo }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: Bundle.main.shortVersion ?? "?")
                Link("Privacy policy", destination: URL(string: "https://sam.ink/bike-lanes/privacy")!)
            }
            Section("Data") {
                Button("Delete all local reports", role: .destructive) {
                    showingEraseConfirm = true
                }
            }
            Section("What this does") {
                Text("Submits anonymous illegal-parking reports to Denver's 311 system. All photo analysis happens on your device; the photo and address are uploaded to Denver.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete all local reports?",
                            isPresented: $showingEraseConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { try? repo.deleteAll() }
        }
    }
}

private extension Bundle {
    var shortVersion: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
}
