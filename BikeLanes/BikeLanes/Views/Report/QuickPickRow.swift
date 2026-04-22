// BikeLanes/Views/Report/QuickPickRow.swift
import SwiftUI

struct QuickPickOption<Value: Hashable>: Identifiable {
    let label: String
    let value: Value
    var id: Value { value }
}

struct QuickPickRow<Value: Hashable>: View {
    let label: String
    let options: [QuickPickOption<Value>]
    @Binding var selection: Value?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.88)
                    .foregroundStyle(Color(red: 138/255, green: 135/255, blue: 118/255))
                if selection == nil {
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
                HStack(spacing: 8) {
                    ForEach(options) { opt in
                        pill(opt)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func pill(_ opt: QuickPickOption<Value>) -> some View {
        let selected = selection == opt.value
        return Button {
            selection = opt.value
        } label: {
            Text(opt.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? .white : Color(red: 42/255, green: 54/255, blue: 42/255))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected
                    ? Color(red: 42/255, green: 111/255, blue: 63/255)
                    : Color(red: 239/255, green: 244/255, blue: 236/255))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
