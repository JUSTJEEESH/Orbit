import WidgetKit
import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitPersistence

/// `@unchecked Sendable` wrapper around WidgetKit's non-Sendable completion
/// handlers. The handler is documented to be invoked exactly once after the
/// timeline call finishes, so racing concurrent uses cannot occur.
///
/// Internal (not private) so additional widget files in the bundle can
/// reuse the helper without duplicating the workaround.
struct SendableCompletion<T>: @unchecked Sendable {
    private let body: (T) -> Void
    init(_ body: @escaping (T) -> Void) { self.body = body }
    func invoke(_ value: T) { body(value) }
}

struct RecentMemoryWidget: Widget {
    let kind: String = "com.joshgreen.orbit.widgets.recent"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentMemoryProvider()) { entry in
            RecentMemoryWidgetView(entry: entry)
                .containerBackground(OrbitColor.background, for: .widget)
        }
        .configurationDisplayName("Recent Memory")
        .description("Glance at your most recent capture.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RecentMemoryEntry: TimelineEntry {
    let date: Date
    let memory: Memory?
}

struct RecentMemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentMemoryEntry {
        RecentMemoryEntry(date: Date(), memory: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentMemoryEntry) -> Void) {
        // WidgetKit's completion handler isn't @Sendable. Boxing it as an
        // explicitly unchecked Sendable value is sound here because the
        // handler is documented to be called exactly once.
        let callback = SendableCompletion(completion)
        Task {
            let memory = await fetchLatest()
            callback.invoke(RecentMemoryEntry(date: Date(), memory: memory))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentMemoryEntry>) -> Void) {
        let callback = SendableCompletion(completion)
        Task {
            let memory = await fetchLatest()
            let entry = RecentMemoryEntry(date: Date(), memory: memory)
            // The app calls WidgetCenter.reloadAllTimelines() when data
            // changes, so a long fallback refresh is fine.
            let next = Date().addingTimeInterval(60 * 60)
            callback.invoke(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchLatest() async -> Memory? {
        let storeURL = ModelContainerFactory.appGroupStoreURL(for: "group.com.joshgreen.orbit")
        if storeURL == nil {
            OrbitLog.app.error("Recent-memory widget: App Group container unresolved. Entitlement missing or sandbox blocked.")
        }
        do {
            let container = try ModelContainerFactory.makeContainer(
                mode: .appGroup(identifier: "group.com.joshgreen.orbit")
            )
            let repo = SwiftDataMemoryRepository(modelContainer: container)
            let memory = try await repo.list(filter: MemoryFilter(limit: 1, sort: .newestFirst)).first
            OrbitLog.app.notice("Recent-memory widget: fetched \(memory == nil ? "none" : "one", privacy: .public); storeURL=\(storeURL?.path ?? "<nil>", privacy: .public).")
            return memory
        } catch {
            OrbitLog.app.error("Recent-memory widget: fetch failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

struct RecentMemoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentMemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow
            if let memory = entry.memory {
                Text(headline(memory))
                    .font(headlineFont)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(headlineLineLimit)
                    .minimumScaleFactor(0.85)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                footer(memory)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // When a memory is present, deep-link to Memory Detail; when the
        // widget is empty, fall back to the capture flow so a tap is
        // never wasted on a dead surface.
        .widgetURL(deepLinkURL)
    }

    // MARK: - Pieces

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(OrbitColor.accent)
                .frame(width: 6, height: 6)
            Text("MOST RECENT")
                .font(OrbitTypography.caption)
                .tracking(0.9)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    /// Right-sized per widget family. Recent supports medium + large
    /// (no small variant), so callout on medium, body on large for the
    /// extra vertical room.
    private var headlineFont: Font {
        switch family {
        case .systemLarge: return OrbitTypography.body
        default: return OrbitTypography.callout
        }
    }

    private var headlineLineLimit: Int {
        switch family {
        case .systemLarge: return 8
        default: return 4
        }
    }

    private func footer(_ memory: Memory) -> some View {
        HStack(spacing: 6) {
            if let category = memory.ai.category, !category.isEmpty {
                chip(category)
            }
            Spacer(minLength: 0)
            Text(memory.createdAt.formatted(.relative(presentation: .named)))
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "plus.circle")
                .scaledFont(size: 22, weight: .regular)
                .foregroundStyle(OrbitColor.textTertiary)
            Text("Tap to capture your first memory")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var deepLinkURL: URL? {
        if let memory = entry.memory {
            return URL(string: "orbit://memory/\(memory.id.uuidString)")
        }
        return URL(string: "orbit://capture")
    }

    private func headline(_ memory: Memory) -> String {
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

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(OrbitTypography.caption)
            .foregroundStyle(OrbitColor.accent)
            .padding(.horizontal, OrbitSpacing.xs)
            .padding(.vertical, 2)
            .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.pill))
    }
}
