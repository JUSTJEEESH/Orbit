import SwiftUI
import OrbitKit
import OrbitDesignSystem
import OrbitStore

@main
struct OrbitApp: App {
    /// Either a working environment or the reason the library couldn't be
    /// opened. There is deliberately no third "fallback" state: Orbit never
    /// runs against a stand-in store, because anything captured there would
    /// be silently lost.
    enum LaunchState {
        case ready(AppEnvironment)
        case libraryUnavailable(String)
    }

    @State private var launch: LaunchState
    private let config: AppConfig

    init() {
        // Configure RevenueCat first thing — every other system
        // (paywall, entitlement observer, restore flow) reads through
        // `Purchases.shared`, and `Purchases.configure(...)` must be
        // called exactly once before any of those touch the SDK.
        //
        // The key below is a development/test key — swap to the
        // production public API key from the RevenueCat dashboard
        // before App Store submission, ideally via an xcconfig-fed
        // Info.plist value so DEBUG and Release pick different keys.
        RevenueCatConfig.configure(apiKey: "appl_JQnSEPnRagNJeDHJvgeSYJacJiP")

        let config = AppConfig.resolveFromBundle()
        self.config = config
        self._launch = State(initialValue: Self.openLibrary(config: config))
        OrbitLog.app.notice("Orbit launched — env=\(config.environment.rawValue, privacy: .public)")
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let environment):
                ContentRoot(environment: environment)
                    // A reopened library is a new environment: give it a
                    // fresh view tree so launch tasks and state start over.
                    .id(ObjectIdentifier(environment))
                    .onAppear {
                        // Lets a settings change (iCloud sync) reopen the
                        // library with the new configuration.
                        environment.reopenLibrary = { launch = Self.openLibrary(config: config) }
                    }
            case .libraryUnavailable(let reason):
                StoreRecoveryView(
                    appGroupIdentifier: config.appGroupIdentifier,
                    errorDescription: reason,
                    onRetry: { launch = Self.openLibrary(config: config) }
                )
            }
        }
    }

    /// Opens the production library. Persistence is required to run: if it
    /// fails, the Recovery screen is shown and the store files are left
    /// exactly as they are on disk.
    ///
    /// Wrapped in a signpost so the cold-launch critical path shows up in
    /// Instruments → Points of Interest under "AppEnvironment init", making
    /// it cheap to measure the impact of any future deferral work (or to
    /// catch regressions if something slow gets re-added).
    private static func openLibrary(config: AppConfig) -> LaunchState {
        do {
            let environment = try OrbitSignpost.measureSync("AppEnvironment init") {
                try AppEnvironment.makeProduction(appConfig: config)
            }
            OrbitLog.persistence.notice("Persistence: SwiftData ready (App Group=\(config.appGroupIdentifier, privacy: .public)).")
            return .ready(environment)
        } catch {
            OrbitLog.persistence.fault("Persistence init failed; showing Recovery: \(String(describing: error), privacy: .public)")
            return .libraryUnavailable(String(describing: error))
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
                    themeService: environment.themeService,
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
            // Repair pass: rescue 1.x Siri captures, transcribe voice notes
            // that arrived without a transcript, and finish enrichment that
            // was interrupted. Last, so it never delays the work above.
            await environment.runLaunchMaintenance()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-pull on every foreground so completions + clips surface
            // promptly.
            if newPhase == .active {
                Task { await environment.remindersSync.pullCompletionUpdates() }
                Task { await environment.captureInbox.drain() }
                if environment.appLock.isLocked {
                    Task { await environment.appLock.unlock() }
                }
            } else if newPhase == .background {
                environment.appLock.lockIfEnabled()
            }
        }
        // App lock: the lock screen while locked, and a plain cover while
        // the app is inactive (app switcher, Control Center) so memories
        // never appear in the switcher snapshot.
        .overlay {
            if environment.appLock.isLocked {
                AppLockView(lock: environment.appLock)
            } else if environment.appLock.isEnabled && scenePhase != .active {
                OrbitColor.background.ignoresSafeArea()
            }
        }
        // Deep links (orbit:// URLs) and Spotlight continue-activities
        // are handled inside RootView so they have access to selectedTab
        // + timelinePath. Keep WindowGroup focused on lifecycle hooks.
    }
}
