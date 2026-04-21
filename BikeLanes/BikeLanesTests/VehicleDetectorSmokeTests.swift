import XCTest
import CoreML
@testable import BikeLanes

final class VehicleDetectorSmokeTests: XCTestCase {
    func testModelLoads() throws {
        let config = MLModelConfiguration()
        _ = try YOLOv11nCar(configuration: config)
    }
}
