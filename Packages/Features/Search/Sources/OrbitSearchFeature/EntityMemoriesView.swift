import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

/// Every memory mentioning one person or place — "Everything about Pamela".
struct EntityMemoriesView: View {
    let entity: MentionedEntity
    let load: @MainActor () async throws -> [Memory]

    @State private var memories: [Memory] = []
    @State private var hasLoaded = false

    var body: some View {
        OrbitScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text(subtitle)
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .padding(.bottom, OrbitSpacing.xs)
                    if hasLoaded && memories.isEmpty {
                        OrbitEmptyState(
                            systemImage: entity.kind == .person ? "person" : "mappin",
                            title: "No memories right now",
                            message: "Memories mentioning \(entity.name) will gather here."
                        )
                    }
                    ForEach(memories) { memory in
                        NavigationLink(value: MemoryDetailRoute(memoryID: memory.id)) {
                            SearchResultRow(result: .init(memory: memory, score: 1, highlight: nil))
                        }
                        .buttonStyle(OrbitBloomButtonStyle(tint: OrbitCategoryPalette.tint(for: memory.ai.category)))
                    }
                }
                .padding(.top, OrbitSpacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            memories = (try? await load()) ?? []
            hasLoaded = true
        }
    }

    private var subtitle: String {
        let count = memories.isEmpty ? entity.memoryCount : memories.count
        let noun = count == 1 ? "memory" : "memories"
        let last = entity.lastMentioned.formatted(date: .abbreviated, time: .omitted)
        return "\(count) \(noun) · last mentioned \(last)"
    }
}
