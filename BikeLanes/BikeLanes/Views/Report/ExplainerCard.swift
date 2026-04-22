// BikeLanes/Views/Report/ExplainerCard.swift
import SwiftUI

/// About-and-FAQ card shown under the empty-state photo tiles. Gives the user
/// context on what the app does, where their data goes, and how the on-device
/// ML works — so they can decide whether they trust the flow before shooting
/// a photo.
struct ExplainerCard: View {
    private static let items: [FAQ] = [
        .init(question: "How does this work?",
              answer: "Take or pick a photo of an illegally parked vehicle. Your phone reads the plate, the state, the car color, and the location right out of the photo. You confirm, tap Submit, and the report goes to Denver 311."),
        .init(question: "Does this work offline?",
              answer: "The plate reading, car detection, color analysis, and reverse-geocoding all run on-device — no servers, no tracking. Submitting the finished report does need a network connection, since that's when the photo and case travel to Denver."),
        .init(question: "Where does my data go?",
              answer: "Only the photo and the address go to Denver's 311 system, in the same shape their official web form uses. Every other bit of analysis — OCR, detection boxes, color category — stays on your phone and is never uploaded."),
        .init(question: "Why do I need to sign in?",
              answer: "Reports file under your Denver PocketGov account so Parking Enforcement can follow up with you and post status updates on your case. You only need to sign in once — the app keeps you signed in across launches."),
        .init(question: "What happens after I submit?",
              answer: "Denver's 311 queues the case to Salesforce. You'll get a confirmation with the case number right in the app, and Denver's Parking Enforcement team routes it from there."),
        .init(question: "Who makes this app?",
              answer: "Bike Action Denver is an open-source community project and is not affiliated with, endorsed by, or operated by the City and County of Denver. It uses Denver's public PocketGov 311 API to file the same kind of report you could file on denvergov.org."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Self.items) { item in
                FAQRow(item: item)
                if item.id != Self.items.last?.id {
                    Rectangle().fill(Color(red: 242/255, green: 239/255, blue: 229/255))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 233/255, green: 229/255, blue: 218/255), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

private struct FAQ: Identifiable, Equatable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct FAQRow: View {
    let item: FAQ
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(item.question)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(item.answer)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
