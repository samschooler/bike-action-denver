import XCTest
import CoreLocation
@testable import BikeLanes

final class VeoReportDraftTests: XCTestCase {
    private func filled() -> VeoReportDraft {
        var d = VeoReportDraft()
        d.photoURL = URL(fileURLWithPath: "/tmp/x.jpg")
        d.addressText = "1300 Knox Ct, Denver, CO"
        d.vehicleType = .scooter
        d.onPrivateOrBlocking = false
        d.blockingRamp = false
        return d
    }

    func testFilledDraftIsSubmittable() {
        XCTAssertTrue(filled().isSubmittable)
    }

    func testMissingPhotoNotSubmittable() {
        var d = filled(); d.photoURL = nil
        XCTAssertFalse(d.isSubmittable)
    }

    func testMissingAddressNotSubmittable() {
        var d = filled(); d.addressText = "   "
        XCTAssertFalse(d.isSubmittable)
    }

    func testMissingYesNoNotSubmittable() {
        var d = filled(); d.blockingRamp = nil
        XCTAssertFalse(d.isSubmittable)
    }

    func testVehicleNumberOptional() {
        XCTAssertTrue(filled().isSubmittable) // vehicleNumber empty by default
        XCTAssertEqual(VeoReportDraft.vehicleNumberFallback, "(Didn't find it)")
    }
}
