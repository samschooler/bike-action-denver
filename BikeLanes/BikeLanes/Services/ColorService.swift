// BikeLanes/Services/ColorService.swift
import Foundation
import CoreImage
import UIKit

struct ColorService {
    private static let palette: [(name: String, r: Int, g: Int, b: Int)] = [
        ("Black",  20, 20, 20),
        ("White",  240, 240, 240),
        ("Gray",   128, 128, 128),
        ("Silver", 192, 192, 192),
        ("Red",    200, 20, 20),
        ("Blue",   30, 60, 200),
        ("Green",  30, 140, 60),
        ("Yellow", 240, 210, 40),
        ("Orange", 235, 130, 30),
        ("Brown",  110, 70, 40),
        ("Tan",    200, 170, 130),
        ("Beige",  220, 200, 170),
        ("Gold",   200, 170, 90),
        ("Purple", 120, 60, 160),
    ]

    static func nearestName(r: Int, g: Int, b: Int) -> String {
        palette.min { a, b2 in
            sqDist(r: r, g: g, b: b, to: a) < sqDist(r: r, g: g, b: b, to: b2)
        }!.name
    }

    private static func sqDist(r: Int, g: Int, b: Int,
                               to entry: (name: String, r: Int, g: Int, b: Int)) -> Int {
        let dr = r - entry.r, dg = g - entry.g, db = b - entry.b
        return dr*dr + dg*dg + db*db
    }

    /// Extract the dominant color name from an image (or crop).
    func dominantName(image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
        // CIAreaAverage gives a 1x1 output with the average color.
        let filter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: ci,
                                           kCIInputExtentKey: CIVector(cgRect: ci.extent)])!
        guard let out = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(out, toBitmap: &bitmap, rowBytes: 4,
                            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return Self.nearestName(r: Int(bitmap[0]),
                                g: Int(bitmap[1]),
                                b: Int(bitmap[2]))
    }
}
