import SwiftUI
import UIKit

/// Orbit's color tokens. All colors are solid surfaces — there are no
/// gradients in the design system, and there will be none. Each token resolves
/// dynamically from light/dark variants so callers never need to branch on
/// `colorScheme`.
public enum OrbitColor {
    // MARK: - Surfaces

    /// The deepest background. OLED-black in dark mode for true blacks on
    /// modern iPhones; warm parchment in light mode.
    public static let background = dynamic(
        light: Hex(0xF7F6F2),
        dark:  Hex(0x000000)
    )

    /// The card / sheet surface elevated one step from `background`.
    public static let surface = dynamic(
        light: Hex(0xFFFFFF),
        dark:  Hex(0x0E0E10)
    )

    /// Elevated two steps — modals, popovers.
    public static let surfaceElevated = dynamic(
        light: Hex(0xFFFFFF),
        dark:  Hex(0x16161A)
    )

    /// A subtle filled chip / pill / search bar surface.
    public static let surfaceMuted = dynamic(
        light: Hex(0xEFEDE7),
        dark:  Hex(0x1C1C1F)
    )

    // MARK: - Text

    public static let textPrimary = dynamic(
        light: Hex(0x0A0A0A),
        dark:  Hex(0xF5F5F5)
    )

    public static let textSecondary = dynamic(
        light: Hex(0x5F5E5A),
        dark:  Hex(0x9A9A9F)
    )

    public static let textTertiary = dynamic(
        light: Hex(0x8C8B86),
        dark:  Hex(0x6A6A6E)
    )

    public static let textInverted = dynamic(
        light: Hex(0xFFFFFF),
        dark:  Hex(0x000000)
    )

    // MARK: - Separators

    public static let separator = dynamic(
        light: Hex(0x000000, alpha: 0.08),
        dark:  Hex(0xFFFFFF, alpha: 0.08)
    )

    public static let separatorStrong = dynamic(
        light: Hex(0x000000, alpha: 0.16),
        dark:  Hex(0xFFFFFF, alpha: 0.16)
    )

    // MARK: - Accents (use sparingly, never gradient them)

    /// The default action color.
    public static let accent = dynamic(
        light: Hex(0x0A6BFF),
        dark:  Hex(0x4C8DFF)
    )

    public static let accentWarm = dynamic(
        light: Hex(0xE0541C),
        dark:  Hex(0xFF7A45)
    )

    public static let accentGreen = dynamic(
        light: Hex(0x1B8A5A),
        dark:  Hex(0x35C28A)
    )

    public static let accentRed = dynamic(
        light: Hex(0xD2362F),
        dark:  Hex(0xFF5E58)
    )

    // MARK: - Semantic

    public static let success = accentGreen
    public static let warning = accentWarm
    public static let danger  = accentRed

    // MARK: - Helpers

    private static func dynamic(light: Hex, dark: Hex) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        })
    }
}

/// Internal hex helper. Not exposed — design tokens should always resolve via
/// the named accessors above, never via raw hex at call sites.
struct Hex {
    let uiColor: UIColor
    init(_ rgb: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8)  & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        self.uiColor = UIColor(red: r, green: g, blue: b, alpha: alpha)
    }
}
