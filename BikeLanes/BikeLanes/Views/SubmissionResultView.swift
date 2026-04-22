// BikeLanes/Views/SubmissionResultView.swift
import SwiftUI

struct SubmissionResultView: View {
    let receipt: CaseReceipt
    let vm: ReportViewModel?
    let onDone: () -> Void

    init(receipt: CaseReceipt, vm: ReportViewModel? = nil, onDone: @escaping () -> Void) {
        self.receipt = receipt
        self.vm = vm
        self.onDone = onDone
    }

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
            if let vm {
                BLUStatusRow(
                    mirror: vm.bluMirror,
                    caseId: receipt.id,
                    canRetry: vm.canRetryBLU(denverCaseId: receipt.id),
                    onRetry: { Task { await vm.retryBLU(denverCaseId: receipt.id) } })
                    .padding(.horizontal, 24)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}
