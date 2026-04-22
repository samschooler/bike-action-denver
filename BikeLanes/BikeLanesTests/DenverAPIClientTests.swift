// BikeLanesTests/DenverAPIClientTests.swift
import XCTest
@testable import BikeLanes

final class DenverAPIClientTests: XCTestCase {
    override func setUp() {
        MockURLProtocol.responders.removeAll()
        MockURLProtocol.recordedRequests.removeAll()
    }

    func testFetchMenusReturnsDecoded() async throws {
        MockURLProtocol.responders[DenverEndpoints.menus] = .json("""
            [{"menuType":"Report an Issue","title":"Illegal Parking",
              "caseType":"REQ_ILLEGALPARKING","active":true,
              "sfIssueTemplateId":"a3Gi000000375ai","configuration":"{}",
              "menuQuestions":null,"id":10}]
            """, status: 200)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let menus = try await client.fetchMenus()
        XCTAssertEqual(menus.first?.id, 10)
    }

    func testSearchAddressReturnsEmptyOn204() async throws {
        let url = DenverEndpoints.addressSearch("nothing")
        MockURLProtocol.responders[url] = .status(204)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let results = try await client.searchAddress("nothing")
        XCTAssertTrue(results.isEmpty)
    }

    func testUploadAttachmentSendsMultipart() async throws {
        let id = UUID()
        MockURLProtocol.responders[DenverEndpoints.attachment(id)] = .json("""
            {"caseHistoryId":0,"caseNumber":null,"mimeType":"image/heic",
             "pathToFiles":"p","created":"2026-04-21T00:00:00Z",
             "id":"\(id.uuidString.lowercased())"}
            """, status: 201)
        let client = DenverAPIClient(session: MockURLProtocol.session)
        let resp = try await client.uploadAttachment(id: id, filename: "IMG.HEIC",
                                                     mimeType: "image/heic",
                                                     data: Data([0, 1, 2]))
        XCTAssertEqual(resp.id, id)
        let recorded = MockURLProtocol.recordedRequests.first!
        XCTAssertTrue(recorded.value(forHTTPHeaderField: "Content-Type")?
                        .hasPrefix("multipart/form-data;") ?? false)
    }
}

// Minimal URLProtocol stub. In practice ship once under BikeLanesTests/TestSupport/MockURLProtocol.swift.
final class MockURLProtocol: URLProtocol {
    enum Response { case json(String, status: Int); case status(Int) }
    nonisolated(unsafe) static var responders: [URL: Response] = [:]
    nonisolated(unsafe) static var recordedRequests: [URLRequest] = []

    static var session: URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.recordedRequests.append(request)
        guard let url = request.url, let r = Self.responders[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        switch r {
        case .json(let s, let status):
            let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(s.utf8))
        case .status(let status):
            let resp = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
