// BikeLanes/Services/ImageCropper.swift
import Foundation
import UIKit

enum ImageCropper {
    /// Crops a JPEG/HEIC data blob to the normalized bbox (Vision's coordinate system,
    /// origin bottom-left, 0...1). Returns JPEG data.
    static func cropJPEG(data: Data, normalizedBBox bbox: CGRect) -> Data? {
        guard let image = UIImage(data: data), let cg = image.cgImage else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: bbox.minX * w,
                          y: (1 - bbox.maxY) * h,          // flip Y
                          width: bbox.width * w,
                          height: bbox.height * h)
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped).jpegData(compressionQuality: 0.85)
    }
}
