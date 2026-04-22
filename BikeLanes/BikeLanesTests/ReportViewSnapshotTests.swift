// BikeLanesTests/ReportViewSnapshotTests.swift
//
// Snapshot-capture tests for ReportView: render the SwiftUI hierarchy into a
// UIHostingController, snap a UIImage, and attach it to the test result so a
// human can inspect the visual state in Xcode's Report navigator.

import XCTest
import SwiftUI
import CoreLocation
@testable import BikeLanes

final class ReportViewSnapshotTests: XCTestCase {
    @MainActor
    func testRendersHappyPath() throws {
        let vm = ReportViewModel.preview(state: .happy)
        let host = UIHostingController(rootView: ReportView(vm: vm))
        host.view.frame = .init(x: 0, y: 0, width: 390, height: 844)

        let renderer = UIGraphicsImageRenderer(size: host.view.frame.size)
        let img = renderer.image { ctx in host.view.layer.render(in: ctx.cgContext) }
        add(XCTAttachment(image: img))
    }

    @MainActor
    func testRendersDegradedNoGPS() throws {
        let vm = ReportViewModel.preview(state: .degradedNoGPS)
        let host = UIHostingController(rootView: ReportView(vm: vm))
        host.view.frame = .init(x: 0, y: 0, width: 390, height: 844)

        let renderer = UIGraphicsImageRenderer(size: host.view.frame.size)
        let img = renderer.image { ctx in host.view.layer.render(in: ctx.cgContext) }
        add(XCTAttachment(image: img))
    }
}

extension ReportViewModel {
    @MainActor
    static func preview(state: PreviewState) -> ReportViewModel {
        let vm = ReportViewModel(
            exif: ExifService(),
            geocode: NullGeocode(),
            detector: try! VehicleDetector(),
            plateDetector: nil,
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: NullSubmit())
        switch state {
        case .happy:
            vm.draft.resolvedAddress = DenverAddress(
                addressId: 70424, line1: "2744 W 13th Ave",
                city: "Denver", state: "CO", zip: "80204",
                coordinate: .init(latitude: 39.7363, longitude: -105.0215))
            vm.draft.coordinates = .init(latitude: 39.7363, longitude: -105.0215)
            vm.draft.plate = "DHKQ98"
            vm.draft.plateState = .colorado
            vm.draft.vehicleColor = "Blue"
            vm.draft.vehicleType = .sedan
            vm.draft.locationOfVehicle = .publicProperty
            vm.draft.blockingDriveway = false
            vm.draft.observedAt = .now
        case .degradedNoGPS:
            vm.draft.photoURL = URL(fileURLWithPath: "/tmp/placeholder.jpg")
            vm.draft.plate = "DHKQ98"
        }
        return vm
    }

    enum PreviewState { case happy, degradedNoGPS }
}

// MARK: - Local fakes (private to this file)

private struct NullGeocode: GeocodeResolving {
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress? { nil }
}

private struct NullSubmit: CaseSubmitting {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data) async throws -> AttachmentResponse {
        fatalError("unused in snapshot")
    }
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse {
        fatalError("unused in snapshot")
    }
}
