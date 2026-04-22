// BikeLanes/Views/Report/ColorSwatchRow.swift
import SwiftUI

struct ColorSwatchRow: View {
    @Binding var selection: String?

    private struct Swatch: Identifiable, Hashable {
        let name: String
        let color: Color
        let strokesBorder: Bool
        var id: String { name }
    }

    private static let swatches: [Swatch] = [
        .init(name: "White",  color: Color(red: 0.96, green: 0.96, blue: 0.94), strokesBorder: true),
        .init(name: "Silver", color: Color(red: 0.78, green: 0.78, blue: 0.80), strokesBorder: false),
        .init(name: "Gray",   color: Color(red: 0.48, green: 0.48, blue: 0.50), strokesBorder: false),
        .init(name: "Black",  color: Color(red: 0.10, green: 0.10, blue: 0.11), strokesBorder: false),
        .init(name: "Red",    color: Color(red: 0.78, green: 0.18, blue: 0.20), strokesBorder: false),
        .init(name: "Blue",   color: Color(red: 0.18, green: 0.36, blue: 0.66), strokesBorder: false),
        .init(name: "Green",  color: Color(red: 0.22, green: 0.50, blue: 0.32), strokesBorder: false),
        .init(name: "Yellow", color: Color(red: 0.92, green: 0.80, blue: 0.20), strokesBorder: false),
        .init(name: "Orange", color: Color(red: 0.93, green: 0.51, blue: 0.13), strokesBorder: false),
        .init(name: "Brown",  color: Color(red: 0.42, green: 0.28, blue: 0.18), strokesBorder: false),
        .init(name: "Gold",   color: Color(red: 0.76, green: 0.62, blue: 0.28), strokesBorder: false),
        .init(name: "Tan",    color: Color(red: 0.76, green: 0.66, blue: 0.50), strokesBorder: false),
    ]

    /// True when `selection` doesn't match any predefined swatch — user typed a custom color.
    private var isCustom: Bool {
        guard let s = selection, !s.isEmpty else { return false }
        return !Self.swatches.contains { $0.name.caseInsensitiveCompare(s) == .orderedSame }
    }

    private var customText: Binding<String> {
        Binding(
            get: { isCustom ? (selection ?? "") : "" },
            set: { selection = $0.isEmpty ? nil : $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("COLOR")
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.88)
                    .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
                if (selection ?? "").isEmpty {
                    Text("REQUIRED")
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(Color(red: 179/255, green: 58/255, blue: 58/255))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(red: 253/255, green: 237/255, blue: 233/255))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Self.swatches) { swatch(in: $0) }
                }
                .padding(.vertical, 2)
            }
            TextField("Or type a color", text: customText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(red: 239/255, green: 244/255, blue: 236/255))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func swatch(in s: Swatch) -> some View {
        let isSelected = selection?.caseInsensitiveCompare(s.name) == .orderedSame
        return Button { selection = s.name } label: {
            ZStack {
                Circle()
                    .fill(s.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(
                            s.strokesBorder ? Color.black.opacity(0.12) : Color.clear,
                            lineWidth: 1))
                if isSelected {
                    Circle()
                        .stroke(Color(red: 42/255, green: 111/255, blue: 63/255), lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}
