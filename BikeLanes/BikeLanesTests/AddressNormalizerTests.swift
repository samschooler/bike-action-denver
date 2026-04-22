import XCTest
@testable import BikeLanes

final class AddressNormalizerTests: XCTestCase {
    func testAbbreviatesDirectionalsAndSuffixes() {
        XCTAssertEqual(AddressNormalizer.normalize("2744 West 13th Avenue"),
                       "2744 W 13th Ave")
        XCTAssertEqual(AddressNormalizer.normalize("1400 North Colfax Street"),
                       "1400 N Colfax St")
        XCTAssertEqual(AddressNormalizer.normalize("200 South Broadway Boulevard"),
                       "200 S Broadway Blvd")
    }

    func testPreservesAlreadyShortForms() {
        XCTAssertEqual(AddressNormalizer.normalize("2744 W 13th Ave"),
                       "2744 W 13th Ave")
    }

    func testBuildsQueryString() {
        XCTAssertEqual(AddressNormalizer.denverQuery(line1: "2744 W 13th Ave"),
                       "2744 W 13th Ave, Denver, CO")
    }
}
