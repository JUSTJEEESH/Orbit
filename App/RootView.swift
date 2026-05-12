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
                        linkFetcher: env.linkFetcher
                    ),
                    onCompleted: { memoryID in
                        env.memoriesDidChange()
                        env.scheduleEnrichment(for: memoryID)
                        env.requestedModal = nil
                    },
                    onCancel: { env.requestedModal = nil }
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
                    onPresentPaywall: { env.requestedModal = .paywall },
                    onDeleteAccount: { try await env.wipeAccountAndData() },
                    onReindexAll: { await env.reenrichAllMemories() },
                    onDismiss: { env.requestedModal = nil }
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
                        memories: env.memories
                    ),
                    onDismiss: { env.requestedModal = nil }
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
                    refreshToken: env.memoryListVersion,
                    clock: env.clock,
                    makeDetailViewModel: makeDetailViewModel,
                    onPresentRecap: { env.requestedModal = .dailyRecap },
                    onPresentPatterns: { env.requestedModal = .patterns }
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
                makeDetailViewModel: makeDetailViewModel
            )
                .tag(AppTab.timeline)
                .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.systemImage) }
                .toolbar { profileToolbar }

            TasksView(
                viewModel: TasksViewModel(
                    listTasks: env.listTasks,
                    listSuggestions: env.listTaskSuggestions,
                    promote: env.promoteHintToTask,
                    toggleTask: env.toggleTask,
                    updateTaskUseCase: env.updateTask,
                    deleteTaskUseCase: env.deleteTask,
                    memories: env.memories,
                    clock: env.clock
                ),
                refreshToken: env.memoryListVersion
            )
                .tag(AppTab.tasks)
                .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage) }
                .toolbar { profileToolbar }

            NavigationStack {
                SearchView(viewModel: SearchViewModel(searchMemories: env.searchMemories))
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
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
                    .font(.system(size: 22, weight: .regular))
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
