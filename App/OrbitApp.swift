import SwiftUI
import OrbitKit
import OrbitDesignSystem
import OrbitStore

@main
struct OrbitApp: App {
    @State private var environment: AppEnvironment

    init() {
        let config = AppConfig.resolveFromBundle()

        // Persistence is required to run; if init fails we fall back to an
        // in-memory environment so the app still launches and the failure is
        // surfaced through logs and Settings.
        //
        // Wrapped in a signpost so the cold-launch critical path shows up
        // in Instruments → Points of Interest under "AppEnvironment init",
        // making it cheap to measure the impact of any future deferral
        // work (or to catch regressions if something slow gets re-added).
        let env: AppEnvironment
        do {
            env = try OrbitSignpost.measureSync("AppEnvironment init") {
                try AppEnvironment.makeProduction(appConfig: config)
            }
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
                    onComplete: {
                        environment.onboardingComplete = true
                        // First-launch wow moment: plant three intro
                        // memories so Timeline, Search, and the Daily
                        // Recap aren't empty when the user lands on
                        // them. Idempotent — re-onboarding after an
                        // account wipe re-seeds; ordinary launches
                        // never duplicate.
                        Task { @MainActor in
                            await environment.seedWelcomeMemoriesIfNeeded()
                        }
                    },
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
        .environment(\.proGates, environment.proGates)
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
        // Deep links (orbit:// URLs) and Spotlight continue-activities
        // are handled inside RootView so they have access to selectedTab
        // + timelinePath. Keep WindowGroup focused on lifecycle hooks.
    }
}
