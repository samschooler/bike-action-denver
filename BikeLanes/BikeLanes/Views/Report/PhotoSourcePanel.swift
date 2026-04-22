// BikeLanes/Views/Report/PhotoSourcePanel.swift
import SwiftUI

/// Empty-state content shown before the user has picked a photo: two big
/// side-by-side panel buttons for "Take Photo" and "Choose Photo", with icons.
struct PhotoSourcePanel: View {
    let onTakePhoto: () -> Void
    let onChoosePhoto: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            panelButton(
                label: "Take Photo",
                systemImage: "camera",
                action: onTakePhoto)
            panelButton(
                label: "Choose Photo",
                systemImage: "photo.on.rectangle",
                action: onChoosePhoto)
        }
        .padding(.horizontal, 20)
    }

    private func panelButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}
