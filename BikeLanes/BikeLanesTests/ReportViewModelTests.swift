// BikeLanesTests/ReportViewModelTests.swift
import XCTest
import CoreLocation
@testable import BikeLanes

@MainActor
final class ReportViewModelTests: XCTestCase {
    func testHappyPathPopulatesAllFields() async throws {
        let url = Bundle(for: Self.self).url(forResource: "IMG_3239", withExtension: "HEIC")!

        let fakeGeocode = FakeGeocodeService()
        fakeGeocode.stubbed = DenverAddress(
            addressId: 70424, line1: "2744 W 13th Ave",
            city: "Denver", state: "CO", zip: "80204",
            coordinate: .init(latitude: 39.7363, longitude: -105.0215))

        let vm = ReportViewModel(
            exif: ExifService(),
            geocode: fakeGeocode,
            detector: try VehicleDetector(),
            plateDetector: nil,
            plateOCR: PlateOCRService(),
            color: ColorService(),
            api: FakeSubmitAPI())

        try await vm.load(photoURL: url)

        XCTAssertNotNil(vm.draft.coordinates)
        XCTAssertEqual(vm.draft.resolvedAddress?.addressId, 70424)
        XCTAssertNotNil(vm.draft.observedAt)
    }
}

final class FakeGeocodeService: GeocodeResolving, @unchecked Sendable {
    var stubbed: DenverAddress?
    func resolve(coordinate: CLLocationCoordinate2D) async throws -> DenverAddress? { stubbed }
}

final class FakeSubmitAPI: CaseSubmitting, @unchecked Sendable {
    func uploadAttachment(id: UUID, filename: String, mimeType: String, data: Data)
        async throws -> AttachmentResponse {
        try JSONDecoder().decode(AttachmentResponse.self, from: """
            {"caseHistoryId":0,"caseNumber":null,"mimeType":"\(mimeType)",
             "pathToFiles":"p","created":"2026-04-21T00:00:00Z","id":"\(id.uuidString.lowercased())"}
            """.data(using: .utf8)!)
    }
    func createCase(_ r: CreateCaseRequest) async throws -> CreateCaseResponse {
        try JSONDecoder().decode(CreateCaseResponse.self, from: """
            {"inputRecordId":1,"attachmentId":"\(UUID().uuidString.lowercased())",
             "menuId":10,"title":"t","email":"","b2CId":"","anonymousId":"\(UUID().uuidString.lowercased())",
             "created":"2026-04-21T00:00:00Z","closed":null,
             "internalCaseStatus":"queuedForCRM","caseStatus":"New",
             "caseId":null,"caseNumber":null,"resolutionNotes":null,
             "sentStatus":"notSent","sfError":null,"attempts":0,
             "inputRecord":{"userInput":"{}","salesForceInput":null,
                            "created":"2026-04-21T00:00:00Z","caseHistory":null,"id":1},
             "id":42}
            """.data(using: .utf8)!)
    }
}
