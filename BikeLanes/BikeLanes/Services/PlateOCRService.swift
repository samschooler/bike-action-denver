// BikeLanes/Services/PlateOCRService.swift
import Foundation
import Vision
import CoreGraphics
import os

struct PlateReading {
    let text: String
    let confidence: Double
}

struct PlateOCRService {
    private static let log = Logger(subsystem: "ink.sam.bikelanes", category: "PlateOCR")

    /// A reading looks plate-shaped when stripped to alphanumerics it's 4–8 chars and contains
    /// at least one digit. Kept loose — plate-region detection has already narrowed the input
    /// to text-inside-a-plate, so we don't also need regex gymnastics here.
    static func isPlateShaped(_ raw: String) -> Bool {
        let stripped = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard (4...8).contains(stripped.count) else { return false }
        guard stripped.contains(where: { $0.isNumber }) else { return false }
        return true
    }

    /// Static compatibility shim for tests that check filter behaviour against raw strings.
    static func filterPlateCandidates(_ raw: [String]) -> [String] {
        raw.compactMap { s -> String? in
            let normalized = s.uppercased().filter { $0.isLetter || $0.isNumber }
            return isPlateShaped(s) ? normalized : nil
        }
    }

    /// Runs Vision text recognition on a (tightly) cropped CGImage and returns the highest-
    /// confidence plate-shaped reading. Caller is responsible for providing a crop that
    /// already bounds the plate region — run `PlateDetector` first.
    func read(cgImage: CGImage) async throws -> PlateReading? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        let allCandidates = observations.flatMap { $0.topCandidates(5) }

        let loggable = allCandidates
            .map { "\($0.string)[\(String(format: "%.2f", $0.confidence))]" }
            .joined(separator: " | ")
        Self.log.info("OCR candidates (\(allCandidates.count, privacy: .public)): \(loggable, privacy: .public)")

        let best = allCandidates
            .filter { Self.isPlateShaped($0.string) }
            .sorted { $0.confidence > $1.confidence }
            .first

        guard let best else {
            Self.log.info("No plate-shaped text in plate crop")
            return nil
        }
        let normalized = best.string.uppercased().filter { $0.isLetter || $0.isNumber }
        Self.log.info("Picked plate: \(normalized, privacy: .public) conf=\(best.confidence, privacy: .public)")
        return PlateReading(text: normalized, confidence: Double(best.confidence))
    }

    /// Legacy shim for tests that pass JPEG data.
    func read(croppedImageData: Data) async throws -> PlateReading? {
        guard let provider = CGDataProvider(data: croppedImageData as CFData),
              let cg = CGImage(jpegDataProviderSource: provider, decode: nil,
                               shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return try await read(cgImage: cg)
    }
}
