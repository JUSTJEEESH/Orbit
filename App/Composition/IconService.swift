import UIKit
import Observation

/// Manages the home-screen icon variant. Wraps
/// `UIApplication.setAlternateIconName(_:)` and exposes an `Observable`
/// surface so SwiftUI views (Settings) can reflect the currently-active
/// variant.
///
/// The four variants correspond 1:1 to the four `OrbitTheme` ids:
///   - `Orbit-Aurora` (primary — the default, no alternate set)
///   - `Orbit-Sunset`
///   - `Orbit-Cosmic`
///   - `Orbit-Forest`
///
/// Switching is best-effort. If the user hasn't dropped a PNG into the
/// bundle for a given variant yet, `UIApplication` throws and we keep
/// the current icon — the theme switch still takes effect in-app.
@MainActor
@Observable
final class IconService {
    public enum Variant: String, CaseIterable, Sendable {
        case aurora  = "Orbit-Aurora"
        case sunset  = "Orbit-Sunset"
        case cosmic  = "Orbit-Cosmic"
        case forest  = "Orbit-Forest"

        /// Aurora is the project's primary icon (the one configured in
        /// `Assets.xcassets/AppIcon.appiconset`). On iOS,
        /// `setAlternateIconName(nil)` reverts to the primary, so we
        /// flag it here.
        var isPrimary: Bool { self == .aurora }

        /// Maps to the matching `OrbitTheme.id`.
        var themeID: String {
            switch self {
            case .aurora: return "aurora"
            case .sunset: return "sunset"
            case .cosmic: return "cosmic"
            case .forest: return "forest"
            }
        }

        init?(themeID: String) {
            switch themeID {
            case "aurora": self = .aurora
            case "sunset": self = .sunset
            case "cosmic": self = .cosmic
            case "forest": self = .forest
            default: return nil
            }
        }
    }

    public private(set) var current: Variant
    public private(set) var lastError: String?

    init() {
        if let name = UIApplication.shared.alternateIconName,
           let variant = Variant(rawValue: name) {
            self.current = variant
        } else {
            self.current = .aurora
        }
    }

    /// Attempts to switch to `variant`. Silently no-ops when the user
    /// requests the variant that's already active, and surfaces a
    /// human-readable error on `lastError` when the OS rejects the
    /// switch (most commonly: missing PNG asset).
    public func select(_ variant: Variant) async {
        guard variant != current else { return }
        let target: String? = variant.isPrimary ? nil : variant.rawValue
        do {
            try await UIApplication.shared.setAlternateIconName(target)
            current = variant
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
