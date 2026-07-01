// BikeLanes/Views/Report/OnboardingBanner.swift
import SwiftUI

/// First-run banner shown at the top of the Report tab. Dismiss state is
/// persisted in UserDefaults via `@AppStorage` so the banner only appears
/// until the user taps "Got it" once per device.
struct OnboardingBanner: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if !hasSeenOnboarding {
            banner
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandGreen)
                Text("Welcome to Bike Action Denver")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            Text("Spot a car in a bike lane or an improperly parked Veo scooter, snap a photo, and file it in under a minute. Car reports go to Denver 311, Veo reports go to Veo — directly, with no server or tracking in between.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text("Got it")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.brandGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cardStroke, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}
