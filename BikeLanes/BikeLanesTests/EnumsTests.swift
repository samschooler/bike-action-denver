// BikeLanesTests/EnumsTests.swift
import XCTest
@testable import BikeLanes

final class EnumsTests: XCTestCase {
    func testDenverVehicleTypeRoundtripsToDenverWireString() {
        XCTAssertEqual(DenverVehicleType.sedan.wireValue, "Sedan (4 Door)")
        XCTAssertEqual(DenverVehicleType.suv.wireValue, "SUV")
        XCTAssertEqual(DenverVehicleType.pickup.wireValue, "Pickup")
        XCTAssertEqual(DenverVehicleType.allCases.count, 7)
    }

    func testPropertyTypeWire() {
        XCTAssertEqual(PropertyType.publicProperty.wireValue, "Public Property")
        XCTAssertEqual(PropertyType.privateProperty.wireValue, "Private Property")
    }

    func testUSStateTwoLetter() {
        XCTAssertEqual(USState.colorado.code, "CO")
        XCTAssertEqual(USState.california.code, "CA")
        XCTAssertEqual(USState(code: "CO"), .colorado)
        XCTAssertNil(USState(code: "XX"))
    }
}
