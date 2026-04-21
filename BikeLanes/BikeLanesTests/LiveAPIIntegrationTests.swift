// BikeLanesTests/LiveAPIIntegrationTests.swift
import XCTest
@testable import BikeLanes

/// Runs only when the environment variable BIKE_LANES_LIVE_API=1.
/// These tests file real Denver cases — treat with care.
final class LiveAPIIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BIKE_LANES_LIVE_API"] == "1",
                          "Live API tests skipped (set BIKE_LANES_LIVE_API=1 to enable)")
    }

    /// Probes two anonymous-contact variants and records which one Denver accepts.
    func testAnonymousContactShape_probe() async throws {
        let client = DenverAPIClient()

        // Build a minimal case around a known addressId from /api/locations/Addresses/search
        let searches = try await client.searchAddress("2744 W 13th Ave, Denver, CO")
        let addr = try XCTUnwrap(searches.first?.toAddress)

        let menus = try await client.fetchMenus()
        let menu = try XCTUnwrap(menus.first { $0.id == 10 })
        let qs = try await client.fetchMenuQuestions(menuId: 10)

        func answer(_ id: Int) -> String {
            switch id {
            case 20: return "No"
            case 21: return ISO8601DateFormatter().string(from: .now)
            case 22: return "TEST00"
            case 46: return "CO"
            case 47: return "Probe car — please close"
            case 48: return DenverVehicleType.sedan.wireValue
            case 49: return PropertyType.publicProperty.wireValue
            default: return ""
            }
        }
        let caseQuestions = qs.map {
            CreateCaseRequest.CaseQuestion(id: $0.id, question: $0.question,
                                           sfAnswerField: $0.sfAnswerField, answer: answer($0.id))
        }

        func tryVariant(_ contact: CreateCaseRequest.Contact) async -> (ok: Bool, error: String?) {
            let req = CreateCaseRequest(
                comments: "AUTOMATED PROBE — please close",
                attachmentId: nil,
                caseType: .init(menuType: menu.menuType, menuId: menu.id, title: menu.title,
                                name: menu.caseType, sfIssueTemplateId: menu.sfIssueTemplateId,
                                caseQuestions: caseQuestions),
                contact: contact,
                location: .init(
                    address: .init(id: addr.addressId, streetAddress: addr.line1,
                                   city: addr.city, state: addr.state, zip: addr.zip),
                    coordinates: .init(latitude: addr.coordinate.latitude,
                                       longitude: addr.coordinate.longitude),
                    addressFromReverseGeocode: true
                )
            )
            do { _ = try await client.createCase(req); return (true, nil) }
            catch { return (false, "\(error)") }
        }

        let emptyStrings = CreateCaseRequest.Contact(
            anonymous: true, languagePreference: "en",
            firstName: "", lastName: "", email: "", phone: nil)
        let r1 = await tryVariant(emptyStrings)
        print("VARIANT empty-strings → \(r1)")

        // Dashes variant
        let dashes = CreateCaseRequest.Contact(
            anonymous: true, languagePreference: "en",
            firstName: "-", lastName: "-", email: "anonymous@denvergov.org", phone: nil)
        let r2 = await tryVariant(dashes)
        print("VARIANT dashes → \(r2)")

        XCTAssertTrue(r1.ok || r2.ok, "At least one anonymous shape should be accepted")
    }
}
