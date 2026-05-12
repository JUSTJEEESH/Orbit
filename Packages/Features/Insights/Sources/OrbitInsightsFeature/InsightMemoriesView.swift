import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

/// Shows the source memories behind a single insight as a list of cards.
/// Pushed from `PatternsView`. Re-uses the existing memory-detail navigation
/// destination from the host stack.
struct InsightMemoriesView: View {
    let insight: SmartInsight
    let listMemories: ListMemoriesUseCase
    let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel
    let heroNamespace: Namespace.ID

    @State private var memories: [Memory] = []
    @State private var isLoading = true

    var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                    header
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, OrbitSpacing.xxl)
                    } else if memories.isEmpty {
                        Text("These memories aren't available anymore.")
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                    } else {
                        memoryList
                    }
                    Spacer(minLength: 48)
                }
                .padding(.top, OrbitSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            OrbitEyebrow(label: insight.kind.label, suffix: nil, tint: OrbitColor.textTertiary)
            Text(insight.headline)
                .scaledFont(size: 30, weight: .semibold, design: .serif)
                .foregroundStyle(OrbitColor.textPrimary)
            Text(insight.body)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var memoryList: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            ForEach(memories) { memory in
                NavigationLink(value: MemoryDetailRoute(memoryID: memory.id)) {
                    OrbitCard(elevation: .resting) {
                        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                            OrbitEyebrow(
                                label: eyebrowLabel(for: memory),
                                suffix: memory.createdAt.formatted(.relative(presentation: .named)),
                                tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                            )
                            Text(headlineText(for: memory))
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .buttonStyle(OrbitBloomButtonStyle(
                    tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                ))
                .matchedTransitionSource(id: memory.id, in: heroNamespace)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await listMemories()
            let idSet = Set(insight.memoryIDs)
            memories = all
                .filter { idSet.contains($0.id) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            memories = []
        }
    }

    private func eyebrowLabel(for memory: Memory) -> String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        switch memory.content.kind {
        case .text:       return "note"
        case .voiceNote:  return "voice"
        case .image:      return "photo"
        case .link:       return "link"
        case .screenshot: return "screenshot"
        case .location:   return "place"
        }
    }

    private func headlineText(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                                   return s
        case .voiceNote(let transcript, _):                  return transcript ?? "Voice note"
        case .image(let caption):                            return caption ?? "Photo"
        case .link(_, let title, let summary):               return summary ?? title ?? "Link"
        case .screenshot(let ocr):                           return ocr ?? "Screenshot"
        case .location(let name, _, _):                      return name ?? "Location"
        }
    }
}
