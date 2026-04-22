import Foundation
import CoreML
import CoreImage
import Vision
import os

/// Detects license-plate bounding boxes inside an image (typically the full photo, since the
/// model was trained on full vehicle frames with small plates).
///
/// Uses a YOLOv11n fine-tuned on license-plate data exported WITHOUT NMS; we do NMS-adjacent
/// logic ourselves by picking the highest-confidence anchor above threshold. That avoids the
/// Ultralytics CoreML-export bug where the baked-in NMS ignores the runtime confidence param.
struct PlateDetector: @unchecked Sendable {
    private static let log = Logger(subsystem: "ink.sam.bikelanes", category: "PlateDetector")
    private static func slog(_ msg: String) {
        // Dual-log via os_log (Xcode/Console) AND NSLog (idevicesyslog).
        log.info("\(msg)")
        NSLog("[PlateDetector] %@", msg)
    }
    private let model: MLModel

    init() throws {
        let url = try Self.modelURL()
        let config = MLModelConfiguration()
        // Force CPU only. Simulator's MLE5Engine fallback produces degraded results for this
        // ultralytics-exported MLProgram; CPU path matches the Python coremltools prediction.
        config.computeUnits = .cpuOnly
        self.model = try MLModel(contentsOf: url, configuration: config)
    }

    struct Detection: Sendable {
        let box: CGRect?         // nil if no above-threshold box found
        let bestConfidence: Double   // 0…1 max across all anchors
        let statusMessage: String    // human-readable UI diagnostic
    }

    /// Returns a detection with diagnostic info — `box` is set only when confidence crosses threshold.
    func detect(in cgImage: CGImage, confidenceThreshold: Double = 0.25) async throws -> Detection {
        // Use MLFeatureValue's image initializer so Core ML applies the exact preprocessing
        // the model was exported with (color space, scale, crop/fit). Manual BGRA pixel
        // buffers lost confidence because the channel layout / color space didn't match the
        // model's declared input constraint.
        guard let inputDesc = model.modelDescription.inputDescriptionsByName["image"],
              let imageConstraint = inputDesc.imageConstraint else {
            Self.slog("detect: input 'image' has no imageConstraint")
            return .init(box: nil, bestConfidence: 0, statusMessage: "no imageConstraint")
        }
        let imageValue: MLFeatureValue
        do {
            imageValue = try MLFeatureValue(
                cgImage: cgImage,
                constraint: imageConstraint,
                options: [MLFeatureValue.ImageOption.cropAndScale: VNImageCropAndScaleOption.scaleFit.rawValue])
        } catch {
            Self.slog("detect: MLFeatureValue(cgImage:) failed: \(String(describing: error))")
            return .init(box: nil, bestConfidence: 0, statusMessage: "feature value error")
        }

        // scaleFit = letterbox; compute the pad fractions for un-letterboxing the output bbox.
        let srcW = CGFloat(cgImage.width), srcH = CGFloat(cgImage.height)
        let scale = min(CGFloat(imageConstraint.pixelsWide) / srcW,
                        CGFloat(imageConstraint.pixelsHigh) / srcH)
        let drawW = srcW * scale, drawH = srcH * scale
        let padXFrac = Double((CGFloat(imageConstraint.pixelsWide) - drawW) / CGFloat(imageConstraint.pixelsWide))
        let padYFrac = Double((CGFloat(imageConstraint.pixelsHigh) - drawH) / CGFloat(imageConstraint.pixelsHigh))

        let provider = try MLDictionaryFeatureProvider(dictionary: ["image": imageValue])
        let result = try await model.prediction(from: provider)

        let outputName = result.featureNames.first { $0 != "image" } ?? result.featureNames.first!
        guard let array = result.featureValue(for: outputName)?.multiArrayValue else {
            Self.slog("detect: no multiarray output (featureNames=\(result.featureNames))")
            return .init(box: nil, bestConfidence: 0, statusMessage: "no multiarray")
        }
        // Expect shape [1, 5, 8400]: batch=1, (cx, cy, w, h, confidence), anchors=8400
        let shape = array.shape.map(\.intValue)
        Self.slog("detect: raw output shape=\(shape)")
        guard shape.count == 3, shape[0] == 1, shape[1] >= 5 else {
            return .init(box: nil, bestConfidence: 0, statusMessage: "bad shape \(shape)")
        }
        let nAnchors = shape[2]
        let strides = array.strides.map(\.intValue)
        let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)

        // Layout is [1][5][8400]; index(batch=0, channel=c, anchor=a) = c*strides[1] + a*strides[2]
        let s1 = strides[1], s2 = strides[2]
        func val(_ c: Int, _ a: Int) -> Double { Double(ptr[c * s1 + a * s2]) }

        var bestConf: Double = 0
        var bestIdx: Int = -1
        for a in 0..<nAnchors {
            let conf = val(4, a)   // channel 4 = class-0 confidence (single class)
            if conf > bestConf {
                bestConf = conf
                bestIdx = a
            }
        }
        Self.slog("detect: anchors=\(nAnchors) best conf=\(bestConf) idx=\(bestIdx)")
        let confPct = String(format: "%.1f%%", bestConf * 100)
        guard bestIdx >= 0, bestConf >= confidenceThreshold else {
            Self.slog("detect: best below threshold \(confidenceThreshold)")
            return .init(box: nil, bestConfidence: bestConf,
                         statusMessage: "plate conf \(confPct) (threshold \(Int(confidenceThreshold * 100))%)")
        }

        // YOLO raw coords: (xCenter, yCenter, width, height) in 0..640 pixels on the letterboxed canvas.
        let xc = val(0, bestIdx) / 640.0
        let yc = val(1, bestIdx) / 640.0
        let w  = val(2, bestIdx) / 640.0
        let h  = val(3, bestIdx) / 640.0

        // Un-letterbox to SOURCE-image normalized coords.
        let ux = (xc - padXFrac / 2) / (1 - padXFrac)
        let uy = (yc - padYFrac / 2) / (1 - padYFrac)
        let uw = w / (1 - padXFrac)
        let uh = h / (1 - padYFrac)

        // YOLO: origin top-left → Vision: origin bottom-left. Flip Y.
        let minX = ux - uw / 2
        let minYTop = uy - uh / 2
        let minY = 1 - (minYTop + uh)
        Self.slog("detect: bbox src x=\(minX) y=\(minY) w=\(uw) h=\(uh)")
        return .init(box: CGRect(x: minX, y: minY, width: uw, height: uh),
                     bestConfidence: bestConf,
                     statusMessage: "plate \(confPct)")
    }

    private static func modelURL() throws -> URL {
        // Xcode compiles .mlpackage → .mlmodelc into the app bundle.
        guard let url = Bundle.main.url(forResource: "PlateDetectorModel", withExtension: "mlmodelc") else {
            throw NSError(domain: "PlateDetector", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "PlateDetectorModel.mlmodelc not found in bundle"])
        }
        return url
    }
}
