import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitDomain
import OrbitMedia
import OrbitHomeFeature
import OrbitTimelineFeature
import OrbitSearchFeature
import OrbitCaptureFeature
import OrbitSettingsFeature
import OrbitMemoryDetailFeature

struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var selectedTab: AppTab = .home
    @State private var presentedModal: AppModal?

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
            captureFAB
        }
        .sheet(item: $presentedModal) { modal in
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
                        presentedModal = nil
                    },
                    onCancel: { presentedModal = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .settings:
                SettingsView(
                    appConfig: env.appConfig,
                    onDismiss: { presentedModal = nil }
                )
                .presentationDetents([.large])
            }
        }
        .onAppear { Haptics.prepare() }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                listMemories: env.listMemories,
                refreshToken: env.memoryListVersion,
                clock: env.clock
            )
                .tag(AppTab.home)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .toolbar { profileToolbar }

            TimelineView(
                listMemories: env.listMemories,
                deleteMemory: env.deleteMemory,
                refreshToken: env.memoryListVersion,
                makeDetailViewModel: makeDetailViewModel,
                onDataChanged: { env.memoriesDidChange() }
            )
                .tag(AppTab.timeline)
                .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.systemImage) }
                .toolbar { profileToolbar }

            SearchView(viewModel: SearchViewModel(searchMemories: env.searchMemories))
                .tag(AppTab.search)
                .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.systemImage) }
                .toolbar { profileToolbar }
        }
        .tint(OrbitColor.textPrimary)
    }

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presentedModal = .settings
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
            presentedModal = .capture
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
            deleteMemory: env.deleteMemory
        )
    }
}
