// BikeLanesTests/PlateOCRServiceTests.swift
import XCTest
@testable import BikeLanes

final class PlateOCRServiceTests: XCTestCase {
    func testRecognizesPlateShapedStrings() {
        let candidates = ["Hello", "DHKQ98", "COLORADO", "ABC-123", "12"]
        let filtered = PlateOCRService.filterPlateCandidates(candidates)
        XCTAssertEqual(filtered, ["DHKQ98", "ABC-123"])
    }
}
