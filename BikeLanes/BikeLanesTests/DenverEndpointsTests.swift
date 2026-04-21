// BikeLanesTests/DenverEndpointsTests.swift
import XCTest
@testable import BikeLanes

final class DenverEndpointsTests: XCTestCase {
    func testMenusURL() {
        XCTAssertEqual(DenverEndpoints.menus.absoluteString,
                       "https://den.denvergov.org/api/forms/Menus")
    }

    func testMenuQuestionsFilterEncoded() {
        let url = DenverEndpoints.menuQuestions(menuId: 10).absoluteString
        XCTAssertTrue(url.contains("$filter=MenuId%20eq%2010%20AND%20Active"))
        XCTAssertTrue(url.contains("$orderby=Group%20ASC,%20Order%20ASC"))
    }

    func testAddressSearchEncoded() {
        let url = DenverEndpoints.addressSearch("2744 W 13th Ave, Denver, CO").absoluteString
        XCTAssertTrue(url.hasSuffix("/api/locations/Addresses/search/denver/2744%20W%2013th%20Ave,%20Denver,%20CO"))
    }

    func testAttachmentURL() {
        let id = UUID(uuidString: "EC3E203A-149E-4FE5-9E2E-528B227C5F2A")!
        XCTAssertEqual(DenverEndpoints.attachment(id).absoluteString,
                       "https://den.denvergov.org/api/cases/attachments/ec3e203a-149e-4fe5-9e2e-528b227c5f2a")
    }

    func testCasesURL() {
        XCTAssertEqual(DenverEndpoints.cases.absoluteString,
                       "https://den.denvergov.org/api/cases")
    }
}
