// BikeLanesTests/ColorServiceTests.swift
import XCTest
@testable import BikeLanes

final class ColorServiceTests: XCTestCase {
    func testNearestNameMapsCommonRGB() {
        XCTAssertEqual(ColorService.nearestName(r: 255, g: 0, b: 0),   "Red")
        XCTAssertEqual(ColorService.nearestName(r: 10,  g: 10, b: 10),  "Black")
        XCTAssertEqual(ColorService.nearestName(r: 240, g: 240, b: 240),"White")
        XCTAssertEqual(ColorService.nearestName(r: 20,  g: 40, b: 200), "Blue")
    }
}
