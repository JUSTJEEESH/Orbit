import SwiftUI
import OrbitKit
import OrbitDesignSystem

@main
struct OrbitApp: App {
    @State private var environment: AppEnvironment

    init() {
        // Composition root. Real services (repositories, AI, search) are wired
        // here as they come online phase by phase. Today: config + clock only.
        let config = AppConfig.resolveFromBundle()
        self._environment = State(initialValue: AppEnvironment(appConfig: config))

        OrbitLog.app.notice("Orbit launched — env=\(config.environment.rawValue, privacy: .public)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(OrbitColor.textPrimary)
        }
    }
}
