import Foundation
import CoreML
import CoreImage
import CoreGraphics
import ImageIO

struct VehicleDetector: @unchecked Sendable {
    private let model: YOLOv11nCar

    init() throws {
        let config = MLModelConfiguration()
        model = try YOLOv11nCar(configuration: config)
    }

    /// Runs YOLO detection directly on the Core ML model's raw tensor outputs and returns
    /// the highest-confidence "car" bounding box in Vision's normalized image coordinates
    /// (0...1, origin at bottom-left), or nil if no car passes `confidenceThreshold`.
    ///
    /// We parse the model's `confidence` (shape `[N, 80]`) and `coordinates`
    /// (shape `[N, 4]` as `[xCenter, yCenter, width, height]`, normalized 0...1, top-left
    /// origin) outputs directly: the bundled ultralytics export is not a Vision-pipeline-
    /// compatible model — `VNCoreMLRequest` yields `Optional([])` against it because its
    /// outputs are raw `MLMultiArray` tensors, not a `VNRecognizedObjectObservation`
    /// pipeline with NMS + class labels.
    func detect(imageData: Data, confidenceThreshold: Double = 0.25) async throws -> CGRect? {
        guard let cgImage = Self.cgImage(from: imageData) else { return nil }
        guard let pixelBuffer = cgImage.resizedPixelBuffer(to: CGSize(width: 640, height: 640)) else {
            return nil
        }

        let output = try model.prediction(
            image: pixelBuffer,
            iouThreshold: 0.45,
            confidenceThreshold: confidenceThreshold
        )

        let confidence = output.confidence
        let coordinates = output.coordinates
        let nBoxes = confidence.shape[0].intValue
        guard nBoxes > 0 else { return nil }

        // COCO class index for "car" (matches the model's user-defined "names" metadata).
        let carClassIndex = 2
        var bestConf: Double = 0
        var bestIdx: Int = -1
        for i in 0..<nBoxes {
            let c = confidence[[NSNumber(value: i), NSNumber(value: carClassIndex)]].doubleValue
            if c > bestConf {
                bestConf = c
                bestIdx = i
            }
        }
        guard bestIdx >= 0, bestConf >= confidenceThreshold else { return nil }

        let xCenter = coordinates[[NSNumber(value: bestIdx), 0]].doubleValue
        let yCenter = coordinates[[NSNumber(value: bestIdx), 1]].doubleValue
        let w = coordinates[[NSNumber(value: bestIdx), 2]].doubleValue
        let h = coordinates[[NSNumber(value: bestIdx), 3]].doubleValue

        // YOLO emits normalized 0...1 coords with origin at top-left. Vision expects
        // origin at bottom-left, so flip Y to match the rest of the pipeline.
        let minX = xCenter - w / 2
        let minYTop = yCenter - h / 2
        let minY = 1 - (minYTop + h)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }

    // MARK: - Image decoding

    /// Decodes image data (HEIC, JPEG, PNG, etc.) into a CGImage with EXIF orientation
    /// applied. Prefers Core Image because its HEIF decoder is more tolerant than
    /// ImageIO's direct path on the iOS Simulator, which fails with
    /// `decodeImageImp failed - NULL _blockArray` for HEVC-backed HEICs.
    private static func cgImage(from data: Data) -> CGImage? {
        if let ci = CIImage(data: data, options: [.applyOrientationProperty: true]) {
            let ctx = CIContext(options: [.useSoftwareRenderer: true])
            let extent = ci.extent
            if !extent.isInfinite, !extent.isEmpty,
               let rendered = ctx.createCGImage(ci, from: extent) {
                return rendered
            }
        }
        // Fallback for JPEG/PNG if Core Image fails for some reason.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return raw
    }
}

