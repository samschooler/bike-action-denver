// BikeLanes/Views/SubmissionResultView.swift
import SwiftUI

struct SubmissionResultView: View {
    let receipt: CaseReceipt
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .resizable().frame(width: 72, height: 72)
                .foregroundStyle(Color(red: 42/255, green: 111/255, blue: 63/255))
            VStack(spacing: 8) {
                Text("Submitted")
                    .font(.custom("Fraunces", size: 28).weight(.medium))
                if let n = receipt.caseNumber {
                    Text("Denver case \(n)")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                } else {
                    Text("Denver case #\(receipt.id)")
                        .font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
