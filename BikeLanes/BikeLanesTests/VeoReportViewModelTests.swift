import XCTest
import CoreLocation
@testable import BikeLanes

@MainActor
final class VeoReportViewModelTests: XCTestCase {
    final class FakeClient: VeoSubmitting, @unchecked Sendable {
        var submitted: VeoSubmission?
        var tokenCalls = 0, uploadCalls = 0
        func fetchCSRFToken() async throws -> String { tokenCalls += 1; return "TOK" }
        func uploadAttachment(filename: String, mimeType: String, data: Data) async throws -> VeoAttachment {
            uploadCalls += 1
            var a = VeoAttachment(id: "I", fileName: filename, url: "u", deleteURL: "d")
            a.rawJSON = "{\"id\":\"I\"}"; return a
        }
        func submit(_ submission: VeoSubmission) async throws { submitted = submission }
    }
    struct FakeResolver: VeoAddressResolving {
        func addressText(for coordinate: CLLocationCoordinate2D) async -> String? { "1 Main St, Denver, CO" }
    }

    private func tempPhoto() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("veo-\(UUID()).jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: url)
        return url
    }

    private func makeVM(_ client: FakeClient, profile: VeoProfile) -> VeoReportViewModel {
        let store = VeoProfileStore(defaults: UserDefaults(suiteName: "veo.vm.\(UUID())")!)
        store.profile = profile
        return VeoReportViewModel(exif: ExifService(), resolver: FakeResolver(),
                                  client: client, profileStore: store)
    }

    func testSubmitBuildsAndSendsWithoutAuth() async throws {
        let client = FakeClient()
        let vm = makeVM(client, profile: VeoProfile(name: "Sam", email: "veo@sam.ink", phone: "1234567890"))
        vm.draft.photoURL = try tempPhoto()
        vm.draft.addressText = "1 Main St, Denver, CO"
        vm.draft.vehicleType = .scooter
        vm.draft.onPrivateOrBlocking = false
        vm.draft.blockingRamp = false
        await vm.submit()
        XCTAssertNil(vm.lastError)
        XCTAssertTrue(vm.didSubmit)
        XCTAssertEqual(client.tokenCalls, 1)
        XCTAssertEqual(client.uploadCalls, 1)
        XCTAssertNotNil(client.submitted)
    }

    func testSubmitBlockedWhenProfileIncomplete() async throws {
        let client = FakeClient()
        let vm = makeVM(client, profile: VeoProfile())
        vm.draft.photoURL = try tempPhoto()
        vm.draft.vehicleType = .scooter
        await vm.submit()
        XCTAssertNotNil(vm.lastError)
        XCTAssertFalse(vm.didSubmit)
        XCTAssertNil(client.submitted)
    }
}
