// BikeLanes/Views/Report/SubmitButton.swift
import SwiftUI

struct SubmitButton: View {
    let enabled: Bool
    let isLoading: Bool
    let action: () -> Void

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

            Text("Files an anonymous case with Denver 311.\nNo account required.")
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
