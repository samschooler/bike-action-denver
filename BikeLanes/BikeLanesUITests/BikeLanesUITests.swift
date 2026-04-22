import XCTest

final class BikeLanesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBootstrapSmoke() throws {
        // Trivial passing test to prove the UI test target is wired up.
        XCTAssertTrue(true)
    }
}
