// BikeLanesTests/MultipartTests.swift
import XCTest
@testable import BikeLanes

final class MultipartTests: XCTestCase {
    func testFileFieldEncodesCorrectly() {
        let boundary = "----test-boundary-123"
        let fileBytes = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let body = Multipart.body(boundary: boundary, fileField: "file",
                                  filename: "IMG.HEIC", mimeType: "image/heic",
                                  data: fileBytes)
        let prefix = "------test-boundary-123\r\nContent-Disposition: form-data; name=\"file\"; filename=\"IMG.HEIC\"\r\nContent-Type: image/heic\r\n\r\n"
        let suffix = "\r\n------test-boundary-123--\r\n"
        var expected = Data(prefix.utf8)
        expected.append(fileBytes)
        expected.append(Data(suffix.utf8))
        XCTAssertEqual(body, expected)
    }

    func testContentTypeHeader() {
        XCTAssertEqual(Multipart.contentType(boundary: "b"),
                       "multipart/form-data; boundary=----b")
    }
}
