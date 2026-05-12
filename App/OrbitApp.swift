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
            OrbitLog.persistence.notice("Persistence: SwiftData ready (App Group=\(config.appGroupIdentifier, privacy: .public)).")
        } catch {
            OrbitLog.persistence.fault("Persistence init failed, falling back to in-memory: \(String(describing: error), privacy: .public)")
            env = AppEnvironment.makePreview()
        }

        self._environment = State(initialValue: env)
        OrbitLog.app.notice("Orbit launched — env=\(config.environment.rawValue, privacy: .public)")
    }

    var body: some Scene {
        WindowGroup {
            ContentRoot(environment: environment)
        }
    }
}

/// Decides between onboarding and the main shell, and attaches whole-app
/// modifiers (deep links, credential-state refresh) at a single place.
private struct ContentRoot: View {
    let environment: AppEnvironment

    var body: some View {
        Group {
            if environment.onboardingComplete {
                RootView()
            } else {
                OnboardingView(
                    account: environment.account,
                    onComplete: { environment.onboardingComplete = true }
                )
                .orbitTheme(environment.themeService.theme)
            }
        }
        .environment(environment)
        .tint(OrbitColor.textPrimary)
        .task {
            await environment.account.refreshCredentialState()
            await environment.notifications.bootstrap()
            // Start listening for watch transfers. Safe to call repeatedly —
            // WCSession activation is idempotent and any queued files from a
            // prior cold-start arrive after this call.
            environment.watchSession.activate()
        }
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else {
                OrbitLog.app.info("Ignored unrecognized URL: \(url.absoluteString, privacy: .public)")
                return
            }
            switch link {
            case .capture:
                environment.requestedModal = .capture
            case .search:
                // Tab switching needs RootView access; for now, just
                // surface intent. The search tab won't auto-switch until
                // we promote `selectedTab` into the environment.
                OrbitLog.app.info("Deep link search query received.")
            }
        }
    }
}
