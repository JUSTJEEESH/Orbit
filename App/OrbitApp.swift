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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if environment.onboardingComplete {
                RootView()
            } else {
                OnboardingView(
                    account: environment.account,
                    onComplete: { environment.onboardingComplete = true },
                    // Wire the Reminders permission row to enable the full
                    // sync flow (request EventKit + flip the toggle on) so
                    // users discover it during onboarding, not buried in
                    // Settings.
                    onEnableReminders: {
                        await environment.remindersSync.enable()
                    },
                    // Same pattern for Calendar — request EventKit
                    // full access + flip Orbit's sync toggle on so
                    // due-dated tasks start mirroring immediately.
                    onEnableCalendar: {
                        await environment.calendarSync.enable()
                    },
                    // Same idea for Health — prompt HealthKit + persist
                    // the asked-once flag so subsequent visits to the
                    // permissions screen don't re-ask.
                    onEnableHealth: {
                        await environment.healthKit.setEnabled(true)
                    }
                )
                .orbitTheme(environment.themeService.theme)
            }
        }
        .environment(environment)
        .environment(\.reviewPrompts, environment.reviewPrompts)
        .tint(OrbitColor.textPrimary)
        .task {
            await environment.account.refreshCredentialState()
            await environment.notifications.bootstrap()
            // Start listening for watch transfers. Safe to call repeatedly —
            // WCSession activation is idempotent and any queued files from a
            // prior cold-start arrive after this call.
            environment.watchSession.activate()
            // Pull any task completions the user toggled in iOS Reminders
            // while Orbit was suspended.
            await environment.remindersSync.pullCompletionUpdates()
            // Begin listening for Lock-Screen camera content + drain any
            // Safari clips that arrived while we were off-screen.
            environment.captureInbox.start()
            await environment.captureInbox.drain()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-pull on every foreground so completions + clips surface
            // promptly.
            if newPhase == .active {
                Task { await environment.remindersSync.pullCompletionUpdates() }
                Task { await environment.captureInbox.drain() }
            }
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
