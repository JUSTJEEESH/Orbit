import SwiftUI
import Observation
import OrbitDesignSystem

/// Owns the user's selected theme and persists it. Observable so SwiftUI
/// re-renders the whole shell when the user flips themes from Settings.
@MainActor
@Observable
final class ThemeService {
    private static let storageKey = "orbit.theme.id"

    public private(set) var theme: OrbitTheme

    public init() {
        let savedID = UserDefaults.standard.string(forKey: Self.storageKey)
        if let savedID, let match = OrbitTheme.all.first(where: { $0.id == savedID }) {
            self.theme = match
        } else {
            self.theme = .aurora
        }
    }

    public func select(_ theme: OrbitTheme) {
        guard theme != self.theme else { return }
        self.theme = theme
        UserDefaults.standard.set(theme.id, forKey: Self.storageKey)
    }
}
