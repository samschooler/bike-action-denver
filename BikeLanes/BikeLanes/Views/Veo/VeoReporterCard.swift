// BikeLanes/Views/Veo/VeoReporterCard.swift
import SwiftUI

/// Inline reporter-profile editor on the Veo report screen.
///
/// - Blank profile (first report): shows the editable fields expanded.
/// - Complete profile (later reports): collapses to a compact summary with an
///   "Edit" button that expands it back inline.
///
/// Fields bind directly to `VeoProfileStore.profile`, which persists on every
/// keystroke — so the latest values are submitted even if the user edits and
/// taps Submit without tapping Save. "Save" here just collapses the card.
struct VeoReporterCard: View {
    @Bindable var store: VeoProfileStore
    /// nil until first appear, then resolved from profile completeness.
    @State private var expanded: Bool?

    private var isExpanded: Bool { expanded ?? !store.profile.isComplete }

    var body: some View {
        Group {
            if isExpanded { editor } else { summary }
        }
        .onAppear { if expanded == nil { expanded = !store.profile.isComplete } }
    }

    // MARK: Expanded editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            label("Your info (sent to Veo)")
            field("Full name", text: $store.profile.name, content: .name)
            field("Email", text: $store.profile.email, content: .emailAddress,
                  keyboard: .emailAddress, autocap: false)
            field("Phone (optional)", text: $store.profile.phone, content: .telephoneNumber,
                  keyboard: .phonePad)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded = false }
            } label: {
                Text("Save")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(store.profile.isComplete ? Color.brandGreen : Color.secondary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(!store.profile.isComplete)
            Text("Veo needs a name and email to follow up. No Denver account required.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    // MARK: Collapsed summary

    private var summary: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.brandGreen)
            VStack(alignment: .leading, spacing: 2) {
                label("Reporting to Veo as")
                Text(store.profile.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(summaryContact)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Edit") {
                withAnimation(.easeInOut(duration: 0.2)) { expanded = true }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.brandGreen)
        }
    }

    private var summaryContact: String {
        let phone = store.profile.phone.trimmingCharacters(in: .whitespaces)
        return phone.isEmpty ? store.profile.email : "\(store.profile.email) · \(phone)"
    }

    // MARK: Bits

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium)).kerning(0.88)
            .foregroundStyle(Color.mutedLabel)
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       content: UITextContentType, keyboard: UIKeyboardType = .default,
                       autocap: Bool = true) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .textContentType(content)
            .keyboardType(keyboard)
            .autocorrectionDisabled(!autocap)
            .textInputAutocapitalization(autocap ? .sentences : .never)
    }
}
