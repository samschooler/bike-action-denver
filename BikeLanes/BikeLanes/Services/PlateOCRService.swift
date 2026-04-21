// BikeLanes/Services/PlateOCRService.swift
import Foundation
import Vision
import CoreGraphics

struct PlateReading {
    let text: String
    let confidence: Double
}

struct PlateOCRService {
    /// Regex: 5–8 chars, letters/digits/dashes, at least one digit and one letter.
    private static let plateRegex = try! NSRegularExpression(
        pattern: "^(?=.*[A-Z])(?=.*[0-9])[A-Z0-9-]{5,8}$")

    /// Filter OCR candidate strings to plate-shaped ones.
    static func filterPlateCandidates(_ raw: [String]) -> [String] {
        raw.map { $0.uppercased().replacingOccurrences(of: " ", with: "") }
            .filter { string in
                let range = NSRange(location: 0, length: string.utf16.count)
                return plateRegex.firstMatch(in: string, range: range) != nil
            }
    }

    /// Runs Vision text recognition on a cropped image, returns best plate reading or nil.
    func read(croppedImageData: Data) async throws -> PlateReading? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(data: croppedImageData)
        try handler.perform([request])

        let observations = (request.results ?? [])
        let candidates = observations.flatMap { $0.topCandidates(3) }
        let plateLike = candidates
            .filter { Self.filterPlateCandidates([$0.string]).isEmpty == false }
            .sorted { $0.confidence > $1.confidence }

        guard let best = plateLike.first else { return nil }
        return PlateReading(text: best.string.uppercased()
                                    .replacingOccurrences(of: " ", with: ""),
                            confidence: Double(best.confidence))
    }
}
