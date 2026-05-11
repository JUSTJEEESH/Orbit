import SwiftUI

/// A single named theme. Each theme owns one *primary accent* that
/// tints the app's signature surfaces (FAB, recap card, navigation
/// chrome, primary buttons). Category colors stay independent —
/// "travel" should read as warm orange regardless of which theme the
/// user picked, because category color is semantic, not decorative.
public struct OrbitTheme: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let primary: Color
    public let promotionalCopy: String

    public init(id: String, name: String, primary: Color, promotionalCopy: String) {
        self.id = id
        self.name = name
        self.primary = primary
        self.promotionalCopy = promotionalCopy
    }
}

public extension OrbitTheme {
    /// Electric blue. Orbit's default, evokes cool focus.
    static let aurora = OrbitTheme(
        id: "aurora",
        name: "Aurora",
        primary: OrbitColor.accent,
        promotionalCopy: "Cool, focused, electric"
    )

    /// Warm orange. Earthy and energetic, picked up from the travel
    /// category but applied app-wide as a personality choice.
    static let sunset = OrbitTheme(
        id: "sunset",
        name: "Sunset",
        primary: OrbitColor.accentWarm,
        promotionalCopy: "Warm, alive, golden hour"
    )

    /// Muted purple. Reflective, journal-friendly.
    static let cosmic = OrbitTheme(
        id: "cosmic",
        name: "Cosmic",
        primary: OrbitColor.accentPlum,
        promotionalCopy: "Calm, reflective, after-dark"
    )

    /// Vivid green. Optimistic, productive.
    static let forest = OrbitTheme(
        id: "forest",
        name: "Forest",
        primary: OrbitColor.accentGreen,
        promotionalCopy: "Grounded, growing, alive"
    )

    /// The order users see them in the Appearance picker. Aurora first
    /// because it's the default; Sunset / Cosmic / Forest follow the
    /// PRD-specified accent ramp.
    static let all: [OrbitTheme] = [.aurora, .sunset, .cosmic, .forest]
}
