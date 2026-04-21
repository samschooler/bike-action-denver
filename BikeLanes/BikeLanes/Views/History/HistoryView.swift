// BikeLanes/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var vm: HistoryViewModel

    var body: some View {
        List(vm.cases, id: \.localId) { c in
            NavigationLink(destination: CaseDetailView(stored: c)) {
                HistoryRow(stored: c)
            }
        }
        .navigationTitle("My Reports")
        .onAppear { vm.refresh() }
    }
}
