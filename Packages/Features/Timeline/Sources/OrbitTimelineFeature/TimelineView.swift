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
    private let onPresentCapture: @MainActor () -> Void

    @State private var memories: [Memory] = []
    @State private var loadState: LoadState = .idle
    @State private var pendingDeletions: Set<UUID> = []
    @Namespace private var heroNamespace

    private enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    public init(
        listMemories: ListMemoriesUseCase,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void,
        refreshToken: Int = 0,
        makeDetailViewModel: @escaping @MainActor (UUID) -> MemoryDetailViewModel,
        onPresentCapture: @escaping @MainActor () -> Void
    ) {
        self.listMemories = listMemories
        self.removeMemory = removeMemory
        self.refreshToken = refreshToken
        self.makeDetailViewModel = makeDetailViewModel
        self.onPresentCapture = onPresentCapture
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
                        .buttonStyle(OrbitBloomButtonStyle(
                            tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                        ))
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
                        // Surface the destructive swipe as a VoiceOver
                        // custom action so rotor users don't have to know
                        // the two-finger swipe gesture.
                        .accessibilityAction(named: "Delete memory") {
                            deleteRow(memory)
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
                        .accessibilityAddTraits(.isHeader)
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
        OrbitEmptyState(
            systemImage: "tray",
            title: "This is where your memory lives",
            message: "Save your first thought and Orbit will organize the rest.",
            action: .init(title: "Capture a thought") {
                Haptics.play(.tap)
                onPresentCapture()
            }
        )
        .padding(.vertical, OrbitSpacing.xxxl)
    }

    private func errorState(_ message: String) -> some View {
        OrbitErrorState(
            title: "Couldn't load timeline",
            message: message
        )
        .padding(.top, OrbitSpacing.xxl)
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
            OrbitLog.persistence.error("Timeline load failed: \(String(describing: error), privacy: .public)")
            loadState = .failed("Couldn't load your timeline. Try again in a moment.")
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
                OrbitEyebrow(
                    label: eyebrowLabel,
                    suffix: timestamp,
                    tint: OrbitCategoryPalette.tint(for: memory.ai.category)
                )

                HStack(alignment: .top, spacing: OrbitSpacing.sm) {
                    Image(systemName: kindIcon)
                        .scaledFont(size: 14, weight: .regular)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .padding(.top, 3)
                    Text(headline)
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if memory.ai.status == .processing {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(OrbitColor.textTertiary)
                            .frame(width: 5, height: 5)
                        Text("Organizing")
                            .scaledFont(size: 11, weight: .medium)
                            .foregroundStyle(OrbitColor.textTertiary)
                            .tracking(0.8)
                    }
                }
            }
        }
        .contentShape(.rect(cornerRadius: OrbitRadius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to open.")
    }

    private var accessibilityLabel: String {
        var parts: [String] = [eyebrowLabel, headline]
        if eyebrowLabel.lowercased() != kindLabel.lowercased() {
            parts.append(kindLabel)
        }
        parts.append(timestamp)
        return parts.joined(separator: ", ")
    }

    /// The category if the AI labeled it, otherwise the kind. The eyebrow
    /// always says *something* meaningful, even before classification runs.
    private var eyebrowLabel: String {
        if let category = memory.ai.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           !category.isEmpty {
            return category
        }
        return kindLabel
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

// Preview removed — the MemoryDetailViewModel now requires a MediaStorage
// instance which would pull OrbitMedia into the Timeline feature package
// just for the preview. Reinstate when we have a TestSupport package that
// vends an ephemeral environment.
