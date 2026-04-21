import XCTest
@testable import BikeLanes

final class BikeLanesTests: XCTestCase {
    func testBootstrapSmoke() throws {
        // Trivial passing test to prove the unit test target is wired up.
        XCTAssertEqual(1 + 1, 2)
    }
}
