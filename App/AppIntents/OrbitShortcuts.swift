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
    }
}
