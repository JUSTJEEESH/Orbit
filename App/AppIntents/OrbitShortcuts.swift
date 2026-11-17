import AppIntents

/// Exposes Orbit's app intents to Shortcuts and the Action Button. Phrases
/// stay short and natural so Siri parses them reliably.
struct OrbitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureTextIntent(),
            phrases: [
                "Capture to \(.applicationName)",
                "Remember in \(.applicationName)",
                "Add to \(.applicationName)",
            ],
            shortTitle: "Capture",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: FindItemIntent(),
            phrases: [
                "Find something in \(.applicationName)",
                "Where did I put something in \(.applicationName)",
                "Ask \(.applicationName) where something is",
            ],
            shortTitle: "Where Is It?",
            systemImageName: "magnifyingglass"
        )
    }
}
