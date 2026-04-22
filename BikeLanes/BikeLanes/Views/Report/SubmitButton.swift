// BikeLanes/Views/Report/SubmitButton.swift
import SwiftUI

struct SubmitButton: View {
    let enabled: Bool
    let isLoading: Bool
    /// When non-nil, the caption text switches from the anonymous copy to a
    /// "filed under \(name)" version. Pass the profile's display label.
    let signedInAs: String?
    let action: () -> Void

    init(enabled: Bool, isLoading: Bool, signedInAs: String? = nil, action: @escaping () -> Void) {
        self.enabled = enabled
        self.isLoading = isLoading
        self.signedInAs = signedInAs
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                HStack {
                    Text("Submit to Denver")
                        .font(.system(size: 16, weight: .semibold))
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("→").foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(enabled ? Color(red: 42/255, green: 111/255, blue: 63/255)
                                     : Color.secondary.opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(red: 42/255, green: 111/255, blue: 63/255).opacity(0.25),
                        radius: 14, y: 4)
            }
            .disabled(!enabled || isLoading)

            Text(captionText)
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var captionText: String {
        let name = signedInAs ?? "your account"
        return "Files a case with Denver 311 under \(name).\nYou'll get status updates in your PocketGov account."
    }
}
