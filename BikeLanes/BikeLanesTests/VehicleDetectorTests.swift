import XCTest
@testable import BikeLanes

final class VehicleDetectorTests: XCTestCase {
    func testDetectsCarInFixturePhoto() async throws {
        // The original HEIC fixture is HEVC-tile-grid-encoded and cannot be decoded on
        // the iOS Simulator (no hardware HEVC) — every ImageIO / Vision / CIImage path
        // fails with `decodeImageImp failed - NULL _blockArray`. This JPEG is the same
        // photo, re-encoded for portability so the detector test runs headlessly on CI.
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239_car", withExtension: "jpg")!
        let data = try Data(contentsOf: url)
        let detector = try VehicleDetector()
        let bbox = try await detector.detect(imageData: data)
        let b = try XCTUnwrap(bbox)
        // Normalized 0...1 coords; should be non-degenerate.
        XCTAssertGreaterThan(b.width, 0.01)
        XCTAssertGreaterThan(b.height, 0.01)
        XCTAssertTrue((0...1).contains(b.minX + b.width / 2))
        XCTAssertTrue((0...1).contains(b.minY + b.height / 2))
    }
}
