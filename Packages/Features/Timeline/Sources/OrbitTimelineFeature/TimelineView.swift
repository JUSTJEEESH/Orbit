import SwiftUI
import OrbitDesignSystem
import OrbitDomain

public struct TimelineView: View {
    private let listMemories: ListMemoriesUseCase
    private let refreshToken: Int

    @State private var memories: [Memory] = []
    @State private var loadState: LoadState = .idle

    private enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    public init(listMemories: ListMemoriesUseCase, refreshToken: Int = 0) {
        self.listMemories = listMemories
        self.refreshToken = refreshToken
    }

    public var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    Text("Timeline")
                        .font(OrbitTypography.largeTitle)
                        .padding(.top, OrbitSpacing.lg)

                    content

                    Spacer(minLength: 96)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable { await reload() }
        }
        .task(id: refreshToken) { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle:
            emptyState
        case .loading:
            if memories.isEmpty { emptyState } else { memoryList }
        case .loaded:
            if memories.isEmpty { emptyState } else { memoryList }
        case .failed(let message):
            errorState(message)
        }
    }

    private var memoryList: some View {
        LazyVStack(spacing: OrbitSpacing.md) {
            ForEach(sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text(section.title)
                        .font(OrbitTypography.title3)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .padding(.top, OrbitSpacing.sm)
                    ForEach(section.memories) { memory in
                        MemoryRow(memory: memory)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Nothing here yet")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Tap the round button to capture your first memory. Orbit organizes the rest.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, OrbitSpacing.xxl)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Couldn't load timeline")
                .font(OrbitTypography.title3)
            Text(message)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }

    private var sections: [TimelineSection] {
        let grouped = Dictionary(grouping: memories) { memory in
            Calendar.current.startOfDay(for: memory.createdAt)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { day, items in
                TimelineSection(
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
            let result = try await listMemories()
            memories = result
            loadState = .loaded
        } catch {
            loadState = .failed(String(describing: error))
        }
    }
}

private struct TimelineSection {
    let title: String
    let memories: [Memory]
}

private struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        OrbitCard(elevation: .resting) {
            VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                Text(headline)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(4)
                HStack(spacing: OrbitSpacing.xs) {
                    OrbitChip(kindLabel, systemImage: kindIcon)
                    Text(timestamp)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
    }

    private var headline: String {
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
    return TimelineView(
        listMemories: ListMemoriesUseCase(
            repository: InMemoryMemoryRepository(seed: memories)
        )
    )
    .preferredColorScheme(.dark)
}
