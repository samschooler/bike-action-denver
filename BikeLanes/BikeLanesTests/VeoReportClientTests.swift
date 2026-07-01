import XCTest
@testable import BikeLanes

final class VeoReportClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.responders.removeAll()
        MockURLProtocol.recordedRequests.removeAll()
    }

    func testFetchCSRFToken() async throws {
        MockURLProtocol.responders[VeoEndpoints.csrfToken] = .json(
            #"{"current_session":{"csrf_token":"hc:abc"}}"#, status: 200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        let token = try await client.fetchCSRFToken()
        XCTAssertEqual(token, "hc:abc")
    }

    func testUploadAttachmentCapturesRawJSON() async throws {
        let raw = #"{"id":"XYZ","file_name":"IMG.jpg","url":"u","delete_url":"d"}"#
        MockURLProtocol.responders[VeoEndpoints.requestUploads] = .json(raw, status: 200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        let att = try await client.uploadAttachment(filename: "IMG.jpg",
                                                     mimeType: "image/jpeg", data: Data([1,2,3]))
        XCTAssertEqual(att.id, "XYZ")
        XCTAssertEqual(att.rawJSON, raw)
        let recorded = MockURLProtocol.recordedRequests.first!
        XCTAssertTrue(recorded.value(forHTTPHeaderField: "Content-Type")?
            .hasPrefix("multipart/form-data;") ?? false)
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "X-Requested-With"), "XMLHttpRequest")
    }

    func testSubmitSucceedsOn302() async throws {
        MockURLProtocol.responders[VeoEndpoints.requests] = .status(302)
        let client = VeoReportClient(session: MockURLProtocol.session)
        var draft = VeoReportDraft()
        draft.vehicleType = .scooter
        let sub = VeoSubmission(draft: draft, profile: VeoProfile(),
                                attachmentJSON: "{}", csrfToken: "T")
        try await client.submit(sub) // must not throw
        let recorded = MockURLProtocol.recordedRequests.last!
        XCTAssertEqual(recorded.httpMethod, "POST")
        XCTAssertEqual(recorded.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
    }

    func testSubmitThrowsOnNon302() async {
        MockURLProtocol.responders[VeoEndpoints.requests] = .status(200)
        let client = VeoReportClient(session: MockURLProtocol.session)
        var draft = VeoReportDraft(); draft.vehicleType = .scooter
        let sub = VeoSubmission(draft: draft, profile: VeoProfile(),
                                attachmentJSON: "{}", csrfToken: "T")
        do { try await client.submit(sub); XCTFail("expected throw") }
        catch { /* expected */ }
    }
}
