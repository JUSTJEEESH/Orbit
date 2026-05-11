import SwiftUI
import OrbitKit
import OrbitDesignSystem

@main
struct OrbitApp: App {
    @State private var environment: AppEnvironment

    init() {
        let config = AppConfig.resolveFromBundle()

        // Persistence is required to run; if init fails we fall back to an
        // in-memory environment so the app still launches and the failure is
        // surfaced through logs and Settings.
        let env: AppEnvironment
        do {
            env = try AppEnvironment.makeProduction(appConfig: config)
            OrbitLog.persistence.notice("Persistence: SwiftData on-disk ready.")
        } catch {
            OrbitLog.persistence.fault("Persistence init failed, falling back to in-memory: \(String(describing: error), privacy: .public)")
            env = AppEnvironment.makePreview()
        }

        self._environment = State(initialValue: env)
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
