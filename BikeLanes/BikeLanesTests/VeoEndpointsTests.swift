import XCTest
@testable import BikeLanes

final class VeoEndpointsTests: XCTestCase {
    func testURLs() {
        XCTAssertEqual(VeoEndpoints.csrfToken.absoluteString,
                       "https://veoride.zendesk.com/hc/api/internal/csrf_token.json")
        XCTAssertEqual(VeoEndpoints.requestUploads.absoluteString,
                       "https://veoride.zendesk.com/hc/en-us/request_uploads")
        XCTAssertEqual(VeoEndpoints.requests.absoluteString,
                       "https://veoride.zendesk.com/hc/en-us/requests")
    }

    func testConstants() {
        XCTAssertEqual(VeoEndpoints.ticketFormID, "24858990499988")
        XCTAssertEqual(VeoEndpoints.market, "den_denver_-_co")
        XCTAssertEqual(VeoEndpoints.subject, "A vehicle is parked where it doesn\u{2019}t belong")
        XCTAssertEqual(VeoEndpoints.Field.blockingRamp, "24862819814548")
    }
}
