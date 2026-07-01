import XCTest
@testable import BikeLanes

final class VeoVehicleTypeTests: XCTestCase {
    func testWireValues() {
        XCTAssertEqual(VeoVehicleType.bike.wireValue, "bike")
        XCTAssertEqual(VeoVehicleType.eBike.wireValue, "e-bike")
        XCTAssertEqual(VeoVehicleType.scooter.wireValue, "scooter")
        XCTAssertEqual(VeoVehicleType.trike.wireValue, "trike")
        XCTAssertEqual(VeoVehicleType.cosmo.wireValue, "cosmo")
        XCTAssertEqual(VeoVehicleType.apollo.wireValue, "apollo")
        XCTAssertEqual(VeoVehicleType.notApplicable.wireValue, "not_applicable")
    }

    func testDisplayIsHumanReadable() {
        XCTAssertEqual(VeoVehicleType.eBike.display, "E-Bike")
        XCTAssertEqual(VeoVehicleType.scooter.display, "Scooter")
    }
}
