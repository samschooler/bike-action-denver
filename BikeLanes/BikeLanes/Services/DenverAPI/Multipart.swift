// BikeLanes/Services/DenverAPI/Multipart.swift
import Foundation

enum Multipart {
    /// Returns header value like Firefox: `multipart/form-data; boundary=----<given>`.
    static func contentType(boundary: String) -> String {
        "multipart/form-data; boundary=----\(boundary)"
    }

    /// Build a single-file multipart body matching Denver's capture shape.
    /// `boundary` here is the header-shaped boundary value (already `----`-prefixed when
    /// generated via `contentType(boundary:)`); body delimiter = "--" + header-boundary per RFC 2046.
    static func body(boundary: String, fileField: String, filename: String,
                     mimeType: String, data: Data) -> Data {
        var out = Data()
        out.append("--\(boundary)\r\n".asUTF8)
        out.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n".asUTF8)
        out.append("Content-Type: \(mimeType)\r\n\r\n".asUTF8)
        out.append(data)
        out.append("\r\n--\(boundary)--\r\n".asUTF8)
        return out
    }

    static func newBoundary() -> String {
        // Match Firefox's "geckoformboundary<hex>"; any unique token works server-side.
        let hex = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return "bikelanesboundary\(hex)"
    }
}

private extension String {
    var asUTF8: Data { data(using: .utf8) ?? Data() }
}
