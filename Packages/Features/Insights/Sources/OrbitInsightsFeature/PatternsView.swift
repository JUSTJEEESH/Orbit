import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

/// The full "Patterns" screen. Lists every active insight as an expanded
/// card with sparkline + dismiss affordance. Tapping a card pushes a
/// filtered list of source memories.
public struct PatternsView: View {
    @Bindable private var viewModel: InsightsViewModel
    private let listMemories: ListMemoriesUseCase
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    private let onDismiss: @MainActor () -> Void

    @Namespace private var heroNamespace

    public init(
        viewModel: InsightsViewModel,
        listMemories: ListMemoriesUseCase,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.listMemories = listMemories
        self.makeDetailViewModel = makeDetailViewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                        header
                        if viewModel.insights.isEmpty {
                            emptyState
                        } else {
                            insightsList
                        }
                        Spacer(minLength: 48)
                    }
                    .padding(.top, OrbitSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .navigationDestination(for: PatternsRoute.self) { route in
                InsightMemoriesView(
                    insight: route.insight,
                    listMemories: listMemories,
                    makeDetailViewModel: makeDetailViewModel,
                    heroNamespace: heroNamespace
                )
            }
            .navigationDestination(for: MemoryDetailRoute.self) { route in
                MemoryDetailView(
                    viewModel: makeDetailViewModel(route.memoryID),
                    onDeleted: {}
                )
                .navigationTransition(.zoom(sourceID: route.memoryID, in: heroNamespace))
            }
            .task { await viewModel.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text("What's emerging")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text("Quiet patterns")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Observations Orbit notices on your behalf. Nothing is ever shared.")
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, OrbitSpacing.xxs)
        }
    }

    private var insightsList: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            ForEach(viewModel.insights) { insight in
                NavigationLink(value: PatternsRoute(insight: insight)) {
                    InsightCard(insight: insight, density: .expanded)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await viewModel.dismiss(insight.kind) }
                        Haptics.play(.warning)
                    } label: {
                        Label("Not useful", systemImage: "hand.thumbsdown")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        OrbitEmptyState(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "Not enough yet",
            message: "Orbit needs a few weeks of captures before patterns become meaningful. Keep going — quiet shapes emerge as you do."
        )
        .padding(.top, OrbitSpacing.xxl)
    }
}

/// Strongly-typed route for the source-memory list of a single insight.
struct PatternsRoute: Hashable {
    let insight: SmartInsight
}
