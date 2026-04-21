// BikeLanesTests/ExifServiceTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

final class ExifServiceTests: XCTestCase {
    func testReadsGPSFromHEIC() throws {
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239", withExtension: "HEIC")!
        let meta = try ExifService().read(url: url)
        let coord = try XCTUnwrap(meta.coordinates)
        XCTAssertEqual(coord.latitude, 39.7365, accuracy: 0.001)
        XCTAssertEqual(coord.longitude, -105.0210, accuracy: 0.001)
        XCTAssertNotNil(meta.observedAt)
        XCTAssertNotNil(meta.heading)
    }

    func testReturnsNilCoordsWhenAbsent() throws {
        let url = Bundle(for: Self.self).url(forResource: "NoGPS", withExtension: "jpg")!
        let meta = try ExifService().read(url: url)
        XCTAssertNil(meta.coordinates)
    }
}
