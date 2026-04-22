// BikeLanes/Extensions/AppTheme.swift
import SwiftUI
import UIKit

/// Central palette for the app. Every semantic color is defined once here
/// with explicit light + dark variants; views reference `Color.appX` rather
/// than hardcoding `Color(red:green:blue:)` literals, so the whole UI flips
/// cleanly when the system switches appearance.
///
/// Content colors (e.g. the actual vehicle-paint swatches — "a red car is
/// always red") stay inlined at their call sites; those aren't chrome.
extension Color {

    // MARK: - Surfaces

    /// Screen background — warm cream in light, warm near-black in dark.
    /// Matches the LaunchBackground colorset so there's no visual seam on launch.
    static let appBackground      = dynamic(light: 0xFAFAF7, dark: 0x121110)
    /// Card / panel surface that sits ON the background. Was hardcoded `Color.white` everywhere.
    static let appSurface         = dynamic(light: 0xFFFFFF, dark: 0x1F1E1B)
    /// Slight-tint surface for inline callouts (e.g. explainer icon backgrounds).
    static let appSurfaceMuted    = dynamic(light: 0xF2EFE5, dark: 0x2A2924)

    // MARK: - Lines

    /// 1pt card border — was (233,229,218).
    static let appBorder          = dynamic(light: 0xE9E5DA, dark: 0x34322C)
    /// Thin divider between rows in a card — was (242,239,229).
    static let appDivider         = dynamic(light: 0xF2EFE5, dark: 0x2A2823)

    // MARK: - Accent (sage green)

    /// Brand sage green. Stays roughly the same hue in dark mode but nudged
    /// brighter for readable contrast against the dark background.
    static let appAccent          = dynamic(light: 0x2A6F3F, dark: 0x4CA568)
    /// Tint behind success-callout content. Was (231,244,232).
    static let appAccentMuted     = dynamic(light: 0xE7F4E8, dark: 0x1F3A28)
    /// Used as the "input enabled" background behind quick-pick rows.
    static let appAccentInputBg   = dynamic(light: 0xEFF4EC, dark: 0x25302A)

    // MARK: - Danger (red)

    /// Error / destructive red. Was (179,58,58).
    static let appDanger          = dynamic(light: 0xB33A3A, dark: 0xE46A6A)
    /// Background behind error / required callouts. Was (253,237,233).
    static let appDangerMuted     = dynamic(light: 0xFDEDE9, dark: 0x3A1F1F)

    // MARK: - Typography

    /// Small-caps eyebrow / muted label. Was (138,135,118).
    static let appLabelMuted      = dynamic(light: 0x8A8776, dark: 0xA19D89)
    /// Placeholder / low-prominence body text that's still darker than secondary.
    static let appTextDim         = dynamic(light: 0x2A362A, dark: 0xDCDCD4)

    // MARK: - Placeholders

    /// Image-placeholder backdrop (behind AuthedImage + photo detail thumbnails).
    /// Was (239,236,226).
    static let appImagePlaceholder = dynamic(light: 0xEFECE2, dark: 0x26251F)

    // MARK: - Shadows

    /// Subtle shadow that actually registers in both modes. Shadows on a
    /// dark background with black won't be visible at all; in dark mode we
    /// push a darker-still near-black so there's still edge separation.
    static let appShadow          = Color(
        uiColor: .init { trait in
            trait.userInterfaceStyle == .dark
                ? .init(white: 0.0, alpha: 0.55)
                : .init(white: 0.0, alpha: 0.08)
        })

    // MARK: - Helpers

    /// Build a dynamic Color from two sRGB hex integers — `light` and `dark`.
    /// Using hex keeps the palette file short and easy to compare with a
    /// design reference; the bit-shifts read the same way in any editor.
    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(uiColor: .init { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >>  8) & 0xFF) / 255.0,
                blue:  CGFloat( hex        & 0xFF) / 255.0,
                alpha: 1.0)
        })
    }
}
