import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitHomeFeature
import OrbitTimelineFeature
import OrbitSearchFeature
import OrbitCaptureFeature
import OrbitSettingsFeature

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
                CaptureView { presentedModal = nil }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .settings:
                SettingsView(appConfig: env.appConfig) { presentedModal = nil }
                    .presentationDetents([.large])
            }
        }
        .onAppear { Haptics.prepare() }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .toolbar { profileToolbar }

            TimelineView()
                .tag(AppTab.timeline)
                .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.systemImage) }
                .toolbar { profileToolbar }

            SearchView()
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
}
