import SwiftUI

private struct OrbitThemeKey: EnvironmentKey {
    static let defaultValue: OrbitTheme = .aurora
}

public extension EnvironmentValues {
    /// The currently active theme. Read in views that should react to
    /// theme changes (e.g. recap card hero text, FAB primary). Default
    /// is Aurora so previews and unit-test contexts render naturally
    /// without setup.
    var orbitTheme: OrbitTheme {
        get { self[OrbitThemeKey.self] }
        set { self[OrbitThemeKey.self] = newValue }
    }
}

public extension View {
    /// Convenience: set the active theme and tint the view subtree with
    /// the theme's primary accent in one call. Apply at the app root.
    func orbitTheme(_ theme: OrbitTheme) -> some View {
        environment(\.orbitTheme, theme)
            .tint(theme.primary)
    }
}
