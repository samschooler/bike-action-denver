// BikeLanes/Services/ColorService.swift
import Foundation
import CoreImage
import UIKit

struct ColorService {
    /// Map an average RGB triple to a human-readable color name.
    ///
    /// Uses HSV: low-saturation pixels map to the grayscale ramp (black/gray/silver/white)
    /// by brightness; saturated pixels map to a chromatic name by hue. Plain RGB-distance
    /// matching against a saturated palette misclassified muted car paints — a teal BMW
    /// averages ~(80,130,140), which is closer to Gray(128,128,128) than to Blue(30,60,200).
    static func nearestName(r: Int, g: Int, b: Int) -> String {
        let (h, s, v) = rgbToHSV(r: r, g: g, b: b)

        // Achromatic ramp.
        if s < 0.18 {
            switch v {
            case ..<0.22:  return "Black"
            case ..<0.55:  return "Gray"
            case ..<0.82:  return "Silver"
            default:       return "White"
            }
        }

        // Low-value, low-saturation warm hues are earth tones, not orange/red paint.
        if v < 0.35 && h >= 10 && h < 55 { return "Brown" }

        // Chromatic, by hue (degrees 0–360).
        switch h {
        case 0..<12, 345...360:   return "Red"
        case 12..<25:              return v < 0.5 ? "Brown" : "Red"
        case 25..<45:              return v < 0.55 ? "Brown" : "Orange"
        case 45..<65:              return s < 0.55 ? "Tan" : "Yellow"
        case 65..<160:             return "Green"
        case 160..<200:            return "Blue"      // cyan/teal bucket into Blue
        case 200..<260:            return "Blue"
        case 260..<300:            return "Purple"
        case 300..<345:            return v > 0.7 ? "Pink" : "Purple"
        default:                    return "Red"
        }
    }

    /// Extract the dominant color name from an image (or crop).
    func dominantName(image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
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

    // MARK: - RGB → HSV

    /// r/g/b in 0…255 → (hue 0…360, saturation 0…1, value 0…1).
    private static func rgbToHSV(r: Int, g: Int, b: Int) -> (h: Double, s: Double, v: Double) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let mx = max(rf, gf, bf), mn = min(rf, gf, bf)
        let delta = mx - mn
        let v = mx
        let s = mx == 0 ? 0 : delta / mx
        var h: Double = 0
        if delta > 0 {
            if mx == rf       { h = 60 * ((gf - bf) / delta).truncatingRemainder(dividingBy: 6) }
            else if mx == gf  { h = 60 * (((bf - rf) / delta) + 2) }
            else              { h = 60 * (((rf - gf) / delta) + 4) }
            if h < 0 { h += 360 }
        }
        return (h, s, v)
    }
}
