// BikeLanes/Views/Veo/ReportHomeView.swift
import SwiftUI

struct ReportHomeView: View {
    let reportVM: ReportViewModel
    let veoVM: VeoReportViewModel
    let auth: AuthService?
    let veoProfile: VeoProfileStore
    private let bg = Color.appBackground

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingBanner()
                    Text("What are you reporting?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20).padding(.top, 4)

                    NavigationLink {
                        ReportView(vm: reportVM, auth: auth)
                    } label: {
                        chooserCard(icon: "car.fill", title: "Car in a bike lane",
                                    subtitle: "File a Denver 311 case (PocketGov sign-in required)")
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        VeoReportView(vm: veoVM)
                    } label: {
                        chooserCard(icon: "scooter", title: "Scooter or bike",
                                    subtitle: "Report to Veo — no account needed")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 16)
            }
            .background(bg)
            .navigationTitle("Report")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView(auth: auth, veoProfile: veoProfile) } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private func chooserCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 26))
                .foregroundStyle(Color.brandGreen)
                .frame(width: 52, height: 52)
                .background(Color.leadingTile)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.cardStroke, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
