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
                    .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                Text("Welcome to Bike Action Denver")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            Text("Photograph a car parked in a Denver bike lane and this app auto-reads the plate, car, and address — then files a real Denver 311 case under your PocketGov account.")
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
                        .background(Color(red: 42/255, green: 111/255, blue: 63/255))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }
}
