import SwiftUI
import CoreSpotlight
import StoreKit
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    @State private var selectedTab: AppTab = .home
    /// Driven from outside the Timeline view when a Spotlight result or
    /// `orbit://memory/<uuid>` URL needs to land on Memory Detail.
    /// Timeline reads it via an externalPath binding; ordinary
    /// tap-a-card-from-the-list flows still use Timeline's own internal
    /// state, untouched.
    @State private var timelinePath: [MemoryDetailRoute] = []

    var body: some View {
        // `@Bindable` lets external entry points (deep links, AppIntents)
        // share the same sheet binding the UI drives.
        @Bindable var bindableEnv = env

        ZStack(alignment: .bottom) {
            tabContent
            captureFAB
            undoToast
        }
        .animation(OrbitMotion.respectfully(OrbitMotion.smooth, reduceMotion: reduceMotion), value: env.trashNotice)
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
                        considerReviewPrompt(after: .memoryCaptured)
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
                    },
                    onWipeDemoData: {
                        #if DEBUG
                        await env.wipeDemoData()
                        #endif
                    },
                    onOpenRecentlyDeleted: {
                        env.requestedModal = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            env.requestedModal = .recentlyDeleted
                        }
                    },
                    onExportLibrary: { try await env.exportLibrary() },
                    onImportFiles: { urls in try await env.importLibrary(from: urls) },
                    iCloudSync: SettingsSyncState(
                        status: env.settingsSyncStatus,
                        onSetEnabled: { env.setSyncPreference($0 ? .on : .off) }
                    ),
                    appLock: env.appLock,
                    onSetResurfacing: { await env.setResurfacingEnabled($0) }
                )
                .presentationDetents([.large])
            case .recentlyDeleted:
                RecentlyDeletedView(onDismiss: { env.requestedModal = nil })
                    .presentationDetents([.large])
            case .widgetHowTo:
                WidgetHowToView(onDone: {
                    env.requestedModal = nil
                    env.dismissWidgetNudge()
                })
                .presentationDetents([.medium, .large])
            case .whatsNew:
                WhatsNewView(
                    audience: env.whatsNewAudience,
                    rescuedMemoryCount: env.rescuedLegacyMemoryCount,
                    asksAboutSync: env.syncPreference == .undecided,
                    onChooseSync: { turnOn in
                        // Seen first: choosing sync reopens the library,
                        // and the new session must not show this again.
                        env.markWhatsNewSeen()
                        env.requestedModal = nil
                        env.setSyncPreference(turnOn ? .on : .off)
                    },
                    onContinue: {
                        env.markWhatsNewSeen()
                        env.requestedModal = nil
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
                        memories: env.memories,
                        // Free-tier quota is spent only on questions that
                        // were answered — a failure never costs a credit.
                        onAnswered: {
                            env.proGates.recordUsage(.askOrbit)
                            env.reviewPrompts.recordValueEvent(.askAnswered)
                        }
                    ),
                    makeDetailViewModel: makeDetailViewModel,
                    proGateCheck: {
                        env.proGates.canAccess(.askOrbit) ? nil : .askOrbit
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
                    onDismiss: {
                        env.requestedModal = nil
                        requestReviewIfAppropriate(for: .askAnswered)
                    }
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
        .task {
            // What's New after updating (or the iCloud question after
            // onboarding). A beat after launch so it lands on a settled UI,
            // and never over a sheet a deep link already opened.
            guard env.shouldPresentWhatsNew else { return }
            try? await Task.sleep(for: .milliseconds(600))
            if env.requestedModal == nil, env.shouldPresentWhatsNew {
                env.requestedModal = .whatsNew
            }
        }
        .onChange(of: env.pendingMemoryLink) { _, id in
            guard let id else { return }
            env.pendingMemoryLink = nil
            handle(.memory(id: id))
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            // The unique identifier we set in SpotlightIndexer is the
            // memory's UUID string. Reverse it here and route to the
            // memory deep link, which lands on Timeline → Detail.
            guard
                let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let id = UUID(uuidString: raw)
            else { return }
            handle(.memory(id: id))
        }
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else {
                OrbitLog.app.info("Ignored unrecognized URL: \(url.absoluteString, privacy: .public)")
                return
            }
            handle(link)
        }
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
                    listSuggestions: env.listMemorySuggestions,
                    dismissSuggestion: { id in env.dismissSuggestion(memoryID: id) },
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
                    shouldShowYearInReviewBanner: env.shouldOfferYearInReview(),
                    widgetNudge: env.showsWidgetNudge
                        ? HomeWidgetNudge(
                            onShowHow: { env.requestedModal = .widgetHowTo },
                            onDismiss: { env.dismissWidgetNudge() }
                        )
                        : nil
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
            }
            .safeAreaPadding(.bottom, FABLayout.contentClearance)
            .tag(AppTab.home)
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }

            TimelineView(
                listMemories: env.listMemories,
                removeMemory: { id in try await env.removeMemory(id: id) },
                refreshToken: env.memoryListVersion,
                makeDetailViewModel: makeDetailViewModel,
                onPresentCapture: { env.requestedModal = .capture },
                path: $timelinePath
            )
                .safeAreaPadding(.bottom, FABLayout.contentClearance)
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
                        await env.syncTaskReminder(for: task)
                    },
                    onTaskDeleted: { task in
                        await env.remindersSync.removeMirror(for: task)
                        await env.calendarSync.removeMirror(for: task)
                        env.cancelTaskReminder(for: task)
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
                .safeAreaPadding(.bottom, FABLayout.contentClearance)
                .tag(AppTab.tasks)
                .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage) }
                .toolbar { profileToolbar }

            NavigationStack {
                SearchView(
                    viewModel: SearchViewModel(
                        searchMemories: env.searchMemories,
                        removeMemory: { id in try await env.removeMemory(id: id) },
                        listEntities: ListMentionedEntitiesUseCase(repository: env.memories),
                        listMentioning: ListMemoriesMentioningUseCase(repository: env.memories)
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

    private enum FABLayout {
        /// Lifts the button clear of the system tab bar.
        static let tabBarClearance: CGFloat = 72
        /// Extra bottom safe area for tab content, so the last rows (and
        /// their swipe actions) can scroll above the button instead of
        /// sitting underneath it.
        static let contentClearance: CGFloat = OrbitCaptureFAB.diameter + OrbitSpacing.md
    }

    /// Undo for the most recent delete. Sits just above the capture button
    /// and disappears on its own after `undoToastLifetime`.
    @ViewBuilder
    private var undoToast: some View {
        if let notice = env.trashNotice {
            UndoDeleteToast {
                Task { try? await env.restoreMemory(id: notice.memoryID) }
            }
            .padding(.bottom, FABLayout.tabBarClearance + OrbitCaptureFAB.diameter + OrbitSpacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: notice.id) {
                AccessibilityNotification.Announcement("Memory deleted. Undo available.").post()
                try? await Task.sleep(for: Self.undoToastLifetime)
                guard env.trashNotice?.id == notice.id else { return }
                withAnimation(OrbitMotion.respectfully(OrbitMotion.smooth, reduceMotion: reduceMotion)) {
                    env.trashNotice = nil
                }
            }
        }
    }

    private static let undoToastLifetime: Duration = .seconds(6)

    /// Records a value moment and, when `ReviewPromptService` agrees it's a
    /// good time, asks for an App Store rating once the sheet has settled.
    private func considerReviewPrompt(after event: ReviewPromptService.ValueEvent) {
        env.reviewPrompts.recordValueEvent(event)
        requestReviewIfAppropriate(for: event)
    }

    /// Asks for a rating if enough `event` moments have happened (and the
    /// install-age, cooldown and yearly-cap rules allow it).
    private func requestReviewIfAppropriate(for event: ReviewPromptService.ValueEvent) {
        guard env.reviewPrompts.shouldRequestReview(for: event) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard env.requestedModal == nil else { return }
            requestReview()
            env.reviewPrompts.didRequestReview()
        }
    }

    private var captureFAB: some View {
        OrbitCaptureFAB {
            env.requestedModal = .capture
        }
        .padding(.bottom, FABLayout.tabBarClearance)
        .allowsHitTesting(true)
    }

    @MainActor
    private func makeDetailViewModel(for memoryID: UUID) -> MemoryDetailViewModel {
        MemoryDetailViewModel(
            memoryID: memoryID,
            repository: env.memories,
            mediaStorage: env.mediaStorage,
            speechTranscriber: env.speechTranscriber,
            listConnectedMemories: env.listConnectedMemories,
            explainConnections: env.explainConnections,
            dismissSuggestion: { id in env.dismissSuggestion(memoryID: id) },
            removeMemory: { id in try await env.removeMemory(id: id) },
            saveEdits: { id, text, tags in try await env.editMemory(id: id, text: text, tagNames: tags) }
        )
    }

    /// Route an inbound deep link to the appropriate UI surface. Called
    /// from both the URL scheme handler (`orbit://...`) and the Spotlight
    /// `onContinueUserActivity` handler so both paths land memories on
    /// the same place.
    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .capture:
            env.requestedModal = .capture
        case .search:
            selectedTab = .search
        case .yearInReview:
            env.requestedModal = .yearInReview
        case .memory(let id):
            selectedTab = .timeline
            // Replace the stack rather than appending so a second
            // Spotlight tap doesn't grow an ever-deeper push history.
            timelinePath = [MemoryDetailRoute(memoryID: id)]
        }
    }
}
