import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitDomain
import OrbitMedia
import OrbitStore
import OrbitHomeFeature
import OrbitTimelineFeature
import OrbitSearchFeature
import OrbitCaptureFeature
import OrbitSettingsFeature
import OrbitMemoryDetailFeature
import OrbitRecapFeature
import OrbitInsightsFeature
import OrbitTasksFeature
import OrbitAskFeature
import OrbitYearInReviewFeature
import OrbitWellnessFeature

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var selectedTab: AppTab = .home

    var body: some View {
        // `@Bindable` lets external entry points (deep links, AppIntents)
        // share the same sheet binding the UI drives.
        @Bindable var bindableEnv = env

        ZStack(alignment: .bottom) {
            tabContent
            captureFAB
        }
        .orbitTheme(env.themeService.theme)
        .sheet(item: $bindableEnv.requestedModal) { modal in
            switch modal {
            case .capture:
                CaptureView(
                    viewModel: CaptureViewModel(
                        captureMemory: env.captureMemory,
                        mediaStorage: env.mediaStorage,
                        speechTranscriber: env.speechTranscriber,
                        linkFetcher: env.linkFetcher,
                        // Evaluated every recorder tick so a Pro
                        // upgrade lifts the cap mid-recording.
                        voiceCapProvider: {
                            env.proGates.canAccess(.voiceLength)
                                ? nil
                                : ProGateService.freeVoiceSeconds
                        }
                    ),
                    onCompleted: { memoryID in
                        env.memoriesDidChange()
                        env.scheduleEnrichment(for: memoryID)
                        env.scheduleSealedDeliveryIfNeeded(for: memoryID)
                        env.requestedModal = nil
                    },
                    onCancel: { env.requestedModal = nil },
                    onPresentPaywall: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .paywall
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .settings:
                SettingsView(
                    appConfig: env.appConfig,
                    account: env.account,
                    entitlements: env.entitlements,
                    notifications: env.notifications,
                    currentTheme: env.themeService.theme,
                    onSelectTheme: { theme in
                        env.themeService.select(theme)
                        // Mirror the in-app accent to the home-screen
                        // icon. No-op if the variant PNG isn't bundled.
                        if let variant = IconService.Variant(themeID: theme.id) {
                            await env.iconService.select(variant)
                        }
                    },
                    iconError: env.iconService.lastError,
                    onPresentPaywall: {
                        // Match the pattern used elsewhere: dismiss the
                        // current modal first so SwiftUI's sheet(item:)
                        // can re-present cleanly with the new identifier.
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .paywall
                        }
                    },
                    onDeleteAccount: { try await env.wipeAccountAndData() },
                    onDismiss: { env.requestedModal = nil },
                    remindersSyncEnabled: env.remindersSync.isEnabled,
                    remindersAuthorized: env.remindersSync.isAuthorized,
                    remindersDenied: env.remindersSync.authorizationStatus == .denied || env.remindersSync.authorizationStatus == .restricted,
                    remindersLastError: env.remindersSync.lastError,
                    onToggleRemindersSync: { newValue in
                        if newValue {
                            _ = await env.remindersSync.enable()
                        } else {
                            env.remindersSync.disable()
                        }
                    },
                    onOpenRemindersSettings: { env.remindersSync.openSystemSettings() },
                    calendarSyncEnabled: env.calendarSync.isEnabled,
                    calendarAuthorized: env.calendarSync.isAuthorized,
                    calendarDenied: env.calendarSync.authorizationStatus == .denied || env.calendarSync.authorizationStatus == .restricted,
                    calendarLastError: env.calendarSync.lastError,
                    onToggleCalendarSync: { newValue in
                        if newValue {
                            _ = await env.calendarSync.enable()
                        } else {
                            env.calendarSync.disable()
                        }
                    },
                    onOpenCalendarSettings: { env.calendarSync.openSystemSettings() },
                    healthKit: env.healthKit,
                    onSeedDemoData: {
                        #if DEBUG
                        await env.seedDemoData()
                        #endif
                    }
                )
                .presentationDetents([.large])
            case .paywall:
                PaywallView(
                    entitlements: env.entitlements,
                    onDismiss: { env.requestedModal = nil }
                )
                .presentationDetents([.large])
            case .dailyRecap:
                DailyRecapView(
                    viewModel: DailyRecapViewModel(
                        generate: env.generateDailyRecap,
                        memories: env.memories,
                        healthKit: env.healthKit
                    ),
                    onDismiss: { env.requestedModal = nil },
                    // Recap is itself a sheet, so going to capture has
                    // to dismiss first and then re-present — same
                    // pattern Capture uses for the paywall hand-off.
                    onPresentCapture: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .capture
                        }
                    }
                )
                .presentationDetents([.large])
            case .patterns:
                PatternsView(
                    viewModel: InsightsViewModel(generate: env.generateInsights),
                    listMemories: env.listMemories,
                    makeDetailViewModel: makeDetailViewModel,
                    onDismiss: { env.requestedModal = nil }
                )
                .presentationDetents([.large])
            case .askOrbit:
                AskOrbitView(
                    viewModel: AskOrbitViewModel(
                        ask: env.askOrbit,
                        memories: env.memories
                    ),
                    makeDetailViewModel: makeDetailViewModel,
                    // Atomic check-and-record so we never miss a usage
                    // event when a question slips through, and so the
                    // view can't accidentally check twice for one
                    // submission.
                    proGateCheck: {
                        if env.proGates.canAccess(.askOrbit) {
                            env.proGates.recordUsage(.askOrbit)
                            return nil
                        }
                        return .askOrbit
                    },
                    // Match the .proGate(...) pattern: dismiss askOrbit
                    // first so SwiftUI's item-based sheet can re-present
                    // cleanly with the new identifier (.paywall).
                    onPresentPaywall: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .paywall
                        }
                    },
                    onDismiss: { env.requestedModal = nil }
                )
                .presentationDetents([.large])
            case .letter:
                LetterCaptureView(
                    captureMemory: env.captureMemory,
                    onCompleted: { memoryID in
                        env.memoriesDidChange()
                        env.scheduleEnrichment(for: memoryID)
                        env.scheduleSealedDeliveryIfNeeded(for: memoryID)
                        env.requestedModal = nil
                    },
                    onCancel: { env.requestedModal = nil }
                )
                .presentationDetents([.large])
            case .yearInReview:
                YearInReviewView(
                    viewModel: YearInReviewViewModel(generate: env.generateYearInReview),
                    makeDetailViewModel: makeDetailViewModel,
                    isPro: env.entitlements.state.isPro,
                    onPresentPaywall: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .paywall
                        }
                    },
                    onDismiss: {
                        env.requestedModal = nil
                        env.markYearInReviewSeen()
                    }
                )
                .presentationDetents([.large])
            case .gratitude:
                GratitudeCaptureView(
                    viewModel: GratitudeCaptureViewModel(capture: env.captureGratitude),
                    onCompleted: { memoryID in
                        env.memoriesDidChange()
                        env.scheduleEnrichment(for: memoryID)
                        env.requestedModal = nil
                    },
                    onCancel: { env.requestedModal = nil }
                )
                .presentationDetents([.large])
            case .proGate(let gate):
                // Soft contextual paywall. Tapping "See Orbit Pro"
                // dismisses this sheet and queues the full PaywallView
                // after a short delay — SwiftUI's .sheet(item:) needs
                // a beat to complete the dismiss animation before
                // re-presenting cleanly with a new item id.
                ProGateSheet(
                    gate: gate,
                    onSeeProDetails: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .paywall
                        }
                    },
                    onDismiss: { env.requestedModal = nil }
                )
            }
        }
        .onAppear { Haptics.prepare() }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            // Each tab wraps in a NavigationStack so the profile toolbar
            // has a navigation bar to live in. Timeline already manages
            // its own stack for memory-detail navigation.
            NavigationStack {
                HomeView(
                    listMemories: env.listMemories,
                    generateInsights: env.generateInsights,
                    listOnThisDay: env.listOnThisDay,
                    loadGratitudeStatus: env.loadGratitudeStatus,
                    removeMemory: { id in try await env.removeMemory(id: id) },
                    refreshToken: env.memoryListVersion,
                    clock: env.clock,
                    makeDetailViewModel: makeDetailViewModel,
                    onPresentRecap: { env.requestRecap() },
                    onPresentPatterns: { env.requestedModal = .patterns },
                    onPresentAskOrbit: { env.requestedModal = .askOrbit },
                    onPresentLetter: { env.requestedModal = .letter },
                    onPresentYearInReview: { env.requestedModal = .yearInReview },
                    onPresentGratitude: { env.requestedModal = .gratitude },
                    onPresentCapture: { env.requestedModal = .capture },
                    shouldShowYearInReviewBanner: env.shouldOfferYearInReview()
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
            }
            .tag(AppTab.home)
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }

            TimelineView(
                listMemories: env.listMemories,
                removeMemory: { id in try await env.removeMemory(id: id) },
                refreshToken: env.memoryListVersion,
                makeDetailViewModel: makeDetailViewModel,
                onPresentCapture: { env.requestedModal = .capture }
            )
                .tag(AppTab.timeline)
                .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.systemImage) }
                .toolbar { profileToolbar }

            TasksView(
                viewModel: TasksViewModel(
                    listTasks: env.listTasks,
                    listSuggestions: env.listTaskSuggestions,
                    listReminderSuggestions: env.listReminderSuggestions,
                    promote: env.promoteHintToTask,
                    promoteReminder: env.promoteReminderToTask,
                    toggleTask: env.toggleTask,
                    updateTaskUseCase: env.updateTask,
                    deleteTaskUseCase: env.deleteTask,
                    memories: env.memories,
                    clock: env.clock,
                    onTaskMutated: { task in
                        await env.remindersSync.mirror(task)
                        await env.calendarSync.mirror(task)
                    },
                    onTaskDeleted: { task in
                        await env.remindersSync.removeMirror(for: task)
                        await env.calendarSync.removeMirror(for: task)
                    }
                ),
                readingViewModel: ReadingListViewModel(
                    listEntries: env.listReadingItems,
                    updateStatus: env.updateReadingItemStatus
                ),
                habitsViewModel: HabitsViewModel(listHabits: env.listHabits),
                refreshToken: env.memoryListVersion,
                makeDetailViewModel: makeDetailViewModel
            )
                .tag(AppTab.tasks)
                .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage) }
                .toolbar { profileToolbar }

            NavigationStack {
                SearchView(
                    viewModel: SearchViewModel(
                        searchMemories: env.searchMemories,
                        removeMemory: { id in try await env.removeMemory(id: id) }
                    ),
                    makeDetailViewModel: makeDetailViewModel,
                    onPresentCapture: { env.requestedModal = .capture }
                )
                    .navigationTitle("Search")
                    .toolbar { profileToolbar }
            }
            .tag(AppTab.search)
            .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.systemImage) }
        }
        .tint(OrbitColor.textPrimary)
    }

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                env.requestedModal = .settings
            } label: {
                Image(systemName: "person.crop.circle")
                    .scaledFont(size: 22, weight: .regular)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .accessibilityLabel("Settings")
            }
        }
    }

    private var captureFAB: some View {
        OrbitCaptureFAB {
            env.requestedModal = .capture
        }
        // Clears the system tab bar; sits in the safe area above it.
        .padding(.bottom, 72)
        .allowsHitTesting(true)
    }

    @MainActor
    private func makeDetailViewModel(for memoryID: UUID) -> MemoryDetailViewModel {
        MemoryDetailViewModel(
            memoryID: memoryID,
            repository: env.memories,
            mediaStorage: env.mediaStorage,
            speechTranscriber: env.speechTranscriber,
            removeMemory: { id in try await env.removeMemory(id: id) }
        )
    }

    /// Route an inbound deep link to the appropriate UI surface.
    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .capture:
            env.requestedModal = .capture
        case .search:
            selectedTab = .search
        }
    }
}
