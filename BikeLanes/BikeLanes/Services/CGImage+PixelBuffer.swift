import CoreGraphics
import CoreVideo
import Foundation

extension CGImage {
    /// Renders the image into an N×N BGRA CVPixelBuffer, drawn stretch-to-fit. Fast but
    /// distorts aspect ratio — usable for detectors trained on square-stretch inputs.
    func resizedPixelBuffer(to size: CGSize) -> CVPixelBuffer? {
        renderPixelBuffer(to: size) { ctx in
            ctx.draw(self, in: CGRect(origin: .zero, size: size))
        }
    }

    /// Renders the image into an N×N BGRA CVPixelBuffer with letterbox padding — preserves
    /// aspect ratio, pads remaining canvas with gray (114/255 — matches Ultralytics default
    /// letterbox color). YOLO models trained via Ultralytics expect this preprocessing.
    func letterboxedPixelBuffer(to size: CGSize) -> CVPixelBuffer? {
        let srcW = CGFloat(width), srcH = CGFloat(height)
        let scale = min(size.width / srcW, size.height / srcH)
        let drawW = srcW * scale, drawH = srcH * scale
        let originX = (size.width - drawW) / 2
        let originY = (size.height - drawH) / 2

        return renderPixelBuffer(to: size) { ctx in
            // Ultralytics uses 114/255 (midgray) as letterbox padding.
            ctx.setFillColor(CGColor(gray: 114.0/255.0, alpha: 1.0))
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.draw(self, in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        }
    }

    private func renderPixelBuffer(to size: CGSize, draw: (CGContext) -> Void) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            nil, width, height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pb = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        draw(ctx)
        return pb
    }
}
