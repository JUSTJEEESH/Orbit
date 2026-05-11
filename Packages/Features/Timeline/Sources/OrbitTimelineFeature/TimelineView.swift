import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitMemoryDetailFeature

public struct TimelineView: View {
    private let listMemories: ListMemoriesUseCase
    private let removeMemory: @MainActor @Sendable (UUID) async throws -> Void
    private let refreshToken: Int
    private let makeDetailViewModel: @MainActor (UUID) -> MemoryDetailViewModel

    @State private var memories: [Memory] = []
    @State private var loadState: LoadState = .idle
    @State private var pendingDeletions: Set<UUID> = []
    @Namespace private var heroNamespace

    private enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    public init(
        listMemories: ListMemoriesUseCase,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void,
        refreshToken: Int = 0,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel
    ) {
        self.listMemories = listMemories
        self.removeMemory = removeMemory
        self.refreshToken = refreshToken
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Timeline")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: MemoryDetailRoute.self) { route in
                    MemoryDetailView(
                        viewModel: makeDetailViewModel(route.memoryID),
                        onDeleted: { /* env handles refresh + deindex via removeMemory closure */ }
                    )
                    .navigationTransition(.zoom(sourceID: route.memoryID, in: heroNamespace))
                }
        }
        .task(id: refreshToken) { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle:
            emptyState
        case .loading:
            if memories.isEmpty { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { memoryList }
        case .loaded:
            if memories.isEmpty { emptyState } else { memoryList }
        case .failed(let message):
            errorState(message)
        }
    }

    private var memoryList: some View {
        List {
            ForEach(sections, id: \.id) { section in
                Section {
                    ForEach(section.memories) { memory in
                        NavigationLink(value: MemoryDetailRoute(memoryID: memory.id)) {
                            MemoryRow(memory: memory)
                        }
                        .matchedTransitionSource(id: memory.id, in: heroNamespace)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: OrbitSpacing.xxs,
                            leading: 0,
                            bottom: OrbitSpacing.xxs,
                            trailing: 0
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRow(memory)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(section.title)
                        .font(OrbitTypography.title3)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .textCase(nil)
                        .padding(.vertical, OrbitSpacing.xs)
                        .listRowInsets(EdgeInsets(top: OrbitSpacing.lg, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            // Breathing room above the floating capture FAB.
            Color.clear
                .frame(height: 96)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(OrbitColor.background)
        .refreshable { await reload() }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("This is where your memory lives")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Tap the round button to save your first thought. Orbit organizes the rest.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .padding(.vertical, OrbitSpacing.xxxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Couldn't load timeline")
                .font(OrbitTypography.title3)
            Text(message)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
    }

    private var sections: [TimelineSection] {
        let visible = memories.filter { !pendingDeletions.contains($0.id) }
        let grouped = Dictionary(grouping: visible) { memory in
            Calendar.current.startOfDay(for: memory.createdAt)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { day, items in
                TimelineSection(
                    id: day,
                    title: Self.sectionTitle(for: day),
                    memories: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    private static func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func reload() async {
        loadState = .loading
        do {
            memories = try await listMemories()
            loadState = .loaded
        } catch {
            loadState = .failed(String(describing: error))
        }
    }

    private func deleteRow(_ memory: Memory) {
        Haptics.play(.warning)
        // Optimistic remove so the row animates away immediately. If the
        // delete fails we restore from the next reload.
        pendingDeletions.insert(memory.id)
        Task { @MainActor in
            do {
                try await removeMemory(memory.id)
                memories.removeAll { $0.id == memory.id }
            } catch {
                pendingDeletions.remove(memory.id)
            }
        }
    }
}

private struct TimelineSection: Identifiable {
    let id: Date
    let title: String
    let memories: [Memory]
}

private struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text(headline)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

                metadataChips
            }
        }
        .contentShape(.rect(cornerRadius: OrbitRadius.lg))
    }

    @ViewBuilder
    private var metadataChips: some View {
        HStack(spacing: OrbitSpacing.xs) {
            OrbitChip(kindLabel, systemImage: kindIcon)
            if let category = memory.ai.category, !category.isEmpty {
                OrbitChip(category, style: .accent)
            }
            if memory.ai.status == .processing {
                OrbitChip("Organizing…", style: .neutral)
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
            Text(timestamp)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    private var headline: String {
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

    private var kindLabel: String {
        switch memory.content {
        case .text:        return "Note"
        case .voiceNote:   return "Voice"
        case .image:       return "Photo"
        case .link:        return "Link"
        case .screenshot:  return "Screenshot"
        case .location:    return "Place"
        }
    }

    private var kindIcon: String {
        switch memory.content {
        case .text:        return "text.alignleft"
        case .voiceNote:   return "waveform"
        case .image:       return "photo"
        case .link:        return "link"
        case .screenshot:  return "rectangle.on.rectangle"
        case .location:    return "mappin"
        }
    }

    private var timestamp: String {
        memory.createdAt.formatted(.relative(presentation: .named))
    }
}

#Preview {
    let memories = [
        Memory(content: .text("Renew passport before July Guatemala trip."),
               createdAt: Date(), updatedAt: Date()),
        Memory(content: .text("Drone business idea — start with realtor demo."),
               createdAt: Date().addingTimeInterval(-3600), updatedAt: Date()),
    ]
    let repo = InMemoryMemoryRepository(seed: memories)
    let delete = DeleteMemoryUseCase(repository: repo)
    return TimelineView(
        listMemories: ListMemoriesUseCase(repository: repo),
        removeMemory: { id in try await delete(id: id) },
        refreshToken: 0,
        makeDetailViewModel: { id in
            MemoryDetailViewModel(
                memoryID: id,
                repository: repo,
                removeMemory: { try await delete(id: $0) }
            )
        }
    )
    .preferredColorScheme(.dark)
}
