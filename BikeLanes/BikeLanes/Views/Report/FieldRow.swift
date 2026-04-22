// BikeLanes/Views/Report/FieldRow.swift
import SwiftUI

struct FieldRow<Leading: View>: View {
    let label: String
    let value: String?
    let caption: String?
    let missing: Bool
    let leadingWidth: CGFloat
    let onEdit: () -> Void
    let leading: () -> Leading

    init(label: String,
         value: String?,
         caption: String?,
         missing: Bool = false,
         leadingWidth: CGFloat = 44,
         onEdit: @escaping () -> Void,
         @ViewBuilder leading: @escaping () -> Leading) {
        self.label = label
        self.value = value
        self.caption = caption
        self.missing = missing
        self.leadingWidth = leadingWidth
        self.onEdit = onEdit
        self.leading = leading
    }

    var body: some View {
        HStack(spacing: 14) {
            leading()
                .frame(width: leadingWidth, height: 44)
                .background(Color.appAccentInputBg)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.88)
                    .foregroundStyle(Color.appLabelMuted)

                valueText

                if let caption {
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Button("Edit", action: onEdit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    @ViewBuilder
    private var valueText: some View {
        if missing {
            Text(value ?? "Tap to add")
                .font(.system(size: 15, weight: .medium).italic())
                .foregroundStyle(Color.appDanger)
        } else {
            Text(value ?? "Tap to add")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
}
