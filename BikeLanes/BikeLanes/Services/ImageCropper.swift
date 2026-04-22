// BikeLanes/Services/ImageCropper.swift
import Foundation
import UIKit
import CoreImage

enum ImageCropper {
    /// Crops a JPEG/HEIC data blob to the normalized bbox (Vision's coordinate system,
    /// origin bottom-left, 0...1). Returns JPEG data at max quality.
    static func cropJPEG(data: Data, normalizedBBox bbox: CGRect) -> Data? {
        guard let cg = cropCGImage(data: data, normalizedBBox: bbox) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 1.0)
    }

    /// Same crop, but returns a pristine `CGImage` — no re-encode, no compression.
    /// Preferred input for Vision so OCR sees the original pixel data.
    static func cropCGImage(data: Data, normalizedBBox bbox: CGRect) -> CGImage? {
        guard let cg = fullCGImage(data: data) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: bbox.minX * w,
                          y: (1 - bbox.maxY) * h,          // Vision origin bottom-left → CG top-left
                          width: bbox.width * w,
                          height: bbox.height * h)
        return cg.cropping(to: rect)
    }

    /// Decode image bytes into a full-frame CGImage **with EXIF orientation applied**.
    ///
    /// `UIImage(data:).cgImage` returns raw unrotated pixel bytes, which silently breaks
    /// ML models: an iPhone portrait HEIC is stored as landscape bytes + orientation=6,
    /// and feeding those landscape bytes to a YOLO plate detector collapses confidence
    /// from ~0.70 to ~0.002. Using `CIImage` with `.applyOrientationProperty` gives us
    /// a CGImage in the same visual/Vision coordinate system the rest of the pipeline uses.
    static func fullCGImage(data: Data) -> CGImage? {
        if let ci = CIImage(data: data, options: [.applyOrientationProperty: true]) {
            let ctx = CIContext(options: [.useSoftwareRenderer: true])
            let extent = ci.extent
            if !extent.isInfinite, !extent.isEmpty,
               let rendered = ctx.createCGImage(ci, from: extent) {
                return rendered
            }
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return raw
    }
}
