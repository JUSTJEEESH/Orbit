import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// Memories the user deleted in the last 30 days. Restore puts a memory back
/// exactly as it was; Delete Now erases it and its files for good.
struct RecentlyDeletedView: View {
    let onDismiss: @MainActor () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var memories: [Memory] = []
    @State private var hasLoaded = false
    @State private var confirmsEmptyAll = false
    @State private var pendingPermanentDelete: Memory?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recently Deleted")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { onDismiss() }
                    }
                    if !memories.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Delete All", role: .destructive) { confirmsEmptyAll = true }
                        }
                    }
                }
                .confirmationDialog(
                    "Delete all \(memories.count) memories forever?",
                    isPresented: $confirmsEmptyAll,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        Task {
                            try? await env.emptyRecentlyDeleted()
                            Haptics.play(.warning)
                        }
                    }
                } message: {
                    Text("Their photos and recordings are erased too. This can’t be undone.")
                }
                .confirmationDialog(
                    "Delete this memory forever?",
                    isPresented: Binding(
                        get: { pendingPermanentDelete != nil },
                        set: { if !$0 { pendingPermanentDelete = nil } }
                    ),
                    titleVisibility: .visible,
                    presenting: pendingPermanentDelete
                ) { memory in
                    Button("Delete Forever", role: .destructive) {
                        Task {
                            try? await env.deleteMemoryPermanently(id: memory.id)
                            Haptics.play(.warning)
                        }
                    }
                } message: { _ in
                    Text("This can’t be undone.")
                }
        }
        .task(id: env.memoryListVersion) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if memories.isEmpty {
            if hasLoaded {
                OrbitEmptyState(
                    systemImage: "trash",
                    title: "Nothing here",
                    message: "Deleted memories stay here for 30 days, so you can always change your mind."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrbitColor.background)
            } else {
                Color.clear
            }
        } else {
            List {
                Section {
                    ForEach(memories) { memory in
                        row(memory)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Restore", systemImage: "arrow.uturn.backward") { restore(memory) }
                                    .tint(OrbitColor.accentGreen)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete Forever", systemImage: "trash", role: .destructive) {
                                    pendingPermanentDelete = memory
                                }
                            }
                            .contextMenu {
                                Button("Restore", systemImage: "arrow.uturn.backward") { restore(memory) }
                                Button("Delete Forever", systemImage: "trash", role: .destructive) {
                                    pendingPermanentDelete = memory
                                }
                            }
                            .accessibilityAction(named: "Restore") { restore(memory) }
                    }
                } footer: {
                    Text("Memories are erased for good after 30 days.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(OrbitColor.background)
        }
    }

    private func row(_ memory: Memory) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.sm) {
            Image(systemName: Self.symbol(for: memory.content.kind))
                .foregroundStyle(OrbitColor.textSecondary)
                .frame(width: OrbitSpacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                Text(Self.preview(for: memory))
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(2)
                Text(Self.remainingText(for: memory, now: env.clock.now()))
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
            }
        }
        .padding(.vertical, OrbitSpacing.xxs)
    }

    private func restore(_ memory: Memory) {
        Haptics.play(.success)
        Task { try? await env.restoreMemory(id: memory.id) }
    }

    private func load() async {
        memories = (try? await env.memories.list(filter: .recentlyDeleted)) ?? []
        hasLoaded = true
    }

    // MARK: - Formatting

    private static func preview(for memory: Memory) -> String {
        let text: String? = switch memory.content {
        case .text(let s):                      s
        case .voiceNote(let transcript, _):     transcript ?? "Voice note"
        case .image(let caption):               caption ?? "Photo"
        case .link(let url, let title, _):      title ?? url.host() ?? url.absoluteString
        case .screenshot(let ocr):              ocr ?? "Screenshot"
        case .location(let name, _, _):         name ?? "Place"
        }
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (memory.ai.summary ?? "Memory") : trimmed
    }

    private static func symbol(for kind: MemoryContentKind) -> String {
        switch kind {
        case .text:       "text.alignleft"
        case .voiceNote:  "waveform"
        case .image:      "photo"
        case .link:       "link"
        case .screenshot: "rectangle.dashed"
        case .location:   "mappin"
        }
    }

    private static func remainingText(for memory: Memory, now: Date) -> String {
        guard let deletedAt = memory.deletedAt else { return "" }
        let expiry = deletedAt.addingTimeInterval(RecentlyDeletedPolicy.retention)
        let days = max(0, Calendar.current.dateComponents([.day], from: now, to: expiry).day ?? 0)
        switch days {
        case 0:  return "Erased today"
        case 1:  return "1 day left"
        default: return "\(days) days left"
        }
    }
}
