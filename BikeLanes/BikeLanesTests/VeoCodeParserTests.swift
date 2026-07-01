import XCTest
@testable import BikeLanes

final class VeoCodeParserTests: XCTestCase {
    func testPlainCode() {
        XCTAssertEqual(VeoCodeParser.parseVehicleNumber(from: "  ABC123 "), "ABC123")
    }

    func testURLLastPathComponent() {
        XCTAssertEqual(
            VeoCodeParser.parseVehicleNumber(from: "https://www.veoride.com/qr/8891234"),
            "8891234")
    }

    func testURLQueryParam() {
        XCTAssertEqual(
            VeoCodeParser.parseVehicleNumber(from: "https://veoride.com/s?code=VN-42&x=1"),
            "VN-42")
    }

    func testEmpty() {
        XCTAssertEqual(VeoCodeParser.parseVehicleNumber(from: "   "), "")
    }
}
