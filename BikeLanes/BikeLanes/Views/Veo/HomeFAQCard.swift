// BikeLanes/Views/Veo/HomeFAQCard.swift
import SwiftUI

/// General app / philosophy FAQ shown on the Report home screen, below the two
/// reporting tools. Reuses the FAQRow accordion from ExplainerCard. Emphasizes
/// that reports go straight to the city/company with no server or tracking.
struct HomeFAQCard: View {
    private static let items: [FAQ] = [
        .init(question: "What is this?",
              answer: "A fast way to help improve the city around you. See something wrong — a car blocking a bike lane, a Veo scooter dumped across the sidewalk — take a photo and file the report in under a minute, straight from the picture."),
        .init(question: "Where do my reports go?",
              answer: "Straight to the source. Cars in bike lanes go to Denver's official 311 (PocketGov); improperly parked Veo scooters and bikes go to Veo's own support system. The app talks directly to those services."),
        .init(question: "Is there a server? Do you track me?",
              answer: "No. There's no Bike Action server, no account with us, no analytics, and no tracking. Reading the plate, detecting the vehicle, and finding the address all happen on your phone — only the finished report (the photo and the details) goes to the city or the company."),
        .init(question: "When is a scooter actually parked improperly?",
              answer: "A Veo scooter or bike on the sidewalk is fine as long as it's upright and leaves room for a wheelchair or stroller to get past. It's improper if it blocks a bike lane, the sidewalk path, a ramp, a crosswalk, or a driveway — or if it's tipped over. If someone can easily get around it, don't report it."),
        .init(question: "Who makes this?",
              answer: "Bike Action Denver is an open-source community project. It's not affiliated with, endorsed by, or operated by the City of Denver or Veo — it just files the same reports you could file yourself on their official channels."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Self.items) { item in
                FAQRow(item: item)
                if item.id != Self.items.last?.id {
                    Rectangle().fill(Color.cardBackgroundAlt)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .stroke(Color.cardStroke, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
