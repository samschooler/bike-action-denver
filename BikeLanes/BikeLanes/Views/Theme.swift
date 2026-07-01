// BikeLanes/Views/Theme.swift
import SwiftUI
import UIKit

/// App color palette with light + dark variants. Previously the UI hard-coded
/// light-only literals (cream backgrounds, white cards, warm greys) which made
/// dark mode look broken. These adaptive colors resolve per `userInterfaceStyle`.
///
/// Naming mirrors the original literals so usages read clearly. Brand green,
/// danger red, and other accents keep their hue; only lightness adapts.
extension Color {
    /// Dynamic sRGB color from light/dark 0–255 component triples.
    static func adaptive(light: (Double, Double, Double),
                         dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0/255, green: c.1/255, blue: c.2/255, alpha: 1)
        })
    }

    /// Screen background (was 250/250/247 cream).
    static let appBackground = adaptive(light: (250, 250, 247), dark: (20, 21, 19))
    /// Elevated card/panel surface (was Color.white / 240,240,240).
    static let cardBackground = adaptive(light: (255, 255, 255), dark: (32, 33, 31))
    /// Secondary cream card surface (was 242/239/229 and 239/236/226).
    static let cardBackgroundAlt = adaptive(light: (242, 239, 229), dark: (40, 41, 38))
    /// Hairline card border (was 233/229/218).
    static let cardStroke = adaptive(light: (233, 229, 218), dark: (66, 67, 62))
    /// Kerned field-label grey (was 138/135/118).
    static let mutedLabel = adaptive(light: (138, 135, 118), dark: (158, 155, 140))

    /// Brand green — filled buttons, icons, links. Slightly brighter in dark.
    static let brandGreen = adaptive(light: (42, 111, 63), dark: (95, 176, 122))
    /// Dark-green pill text on light green (was 42/54/42).
    static let brandGreenDeep = adaptive(light: (42, 54, 42), dark: (214, 226, 214))
    /// Danger/error red (was 179/58/58 and 200/50/50).
    static let dangerRed = adaptive(light: (179, 58, 58), dark: (240, 120, 112))

    /// Neutral tinted tile behind leading glyphs (was 239/244/236 light green).
    static let leadingTile = adaptive(light: (239, 244, 236), dark: (50, 51, 48))
    /// Green highlight badge/tint (was 231/244/232).
    static let greenTint = adaptive(light: (231, 244, 232), dark: (34, 52, 40))
    /// Light red badge background (was 253/237/233).
    static let dangerTint = adaptive(light: (253, 237, 233), dark: (58, 34, 32))
}
