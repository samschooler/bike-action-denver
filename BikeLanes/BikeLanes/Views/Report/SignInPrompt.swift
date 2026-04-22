// BikeLanes/Views/Report/SignInPrompt.swift
import SwiftUI

/// Empty-state card shown when the user is not signed in. Reporting is gated
/// on a Denver PocketGov account; tapping the button launches the login sheet.
struct SignInPrompt: View {
    let onSignIn: () -> Void
    let onDemoSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to report")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Required by Denver PocketGov")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text("Reports file under your PocketGov account so Denver's Parking Enforcement can follow up with you and post status updates on the case. You'll only need to sign in once.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onSignIn) {
                HStack {
                    Text("Sign in with Denver PocketGov")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(red: 42/255, green: 111/255, blue: 63/255))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onDemoSignIn) {
                HStack {
                    Text("Sign in with Bike Action Denver")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(red: 42/255, green: 111/255, blue: 63/255), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("Use the Bike Action Denver demo account for a simulated walkthrough. Submissions won't file real reports.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
