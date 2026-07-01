import Foundation

/// Extracts a Veo vehicle number from a scanned QR/barcode payload.
/// Veo handlebar QRs may encode a bare id or a URL; this normalizes both.
enum VeoCodeParser {
    private static let idQueryKeys = ["code", "id", "vehicle", "number", "qr"]

    static func parseVehicleNumber(from payload: String) -> String {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme, scheme.hasPrefix("http") else {
            return trimmed
        }
        // Prefer a recognizable query param, else the last non-empty path component.
        if let item = comps.queryItems?.first(where: { idQueryKeys.contains($0.name.lowercased()) }),
           let value = item.value, !value.isEmpty {
            return value
        }
        let last = comps.path.split(separator: "/").last.map(String.init)
        return last ?? trimmed
    }
}
