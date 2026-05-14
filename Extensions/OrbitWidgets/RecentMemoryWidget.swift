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
    let kind: String = "com.orbit.app.widgets.recent"

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
        let storeURL = ModelContainerFactory.appGroupStoreURL(for: "group.com.orbit.app")
        if storeURL == nil {
            OrbitLog.app.error("Recent-memory widget: App Group container unresolved. Entitlement missing or sandbox blocked.")
        }
        do {
            let container = try ModelContainerFactory.makeContainer(
                mode: .appGroup(identifier: "group.com.orbit.app")
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
    let entry: RecentMemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text("Most recent")
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)

            if let memory = entry.memory {
                Text(headline(memory))
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(4)
                Spacer()
                HStack(spacing: OrbitSpacing.xs) {
                    if let category = memory.ai.category, !category.isEmpty {
                        chip(category)
                    }
                    Spacer()
                    Text(memory.createdAt.formatted(.relative(presentation: .named)))
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            } else {
                Spacer()
                Text("Nothing here yet")
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Tap to capture your first memory.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // When a memory is present, deep-link to Memory Detail; when the
        // widget is empty, fall back to the capture flow so a tap is
        // never wasted on a dead surface.
        .widgetURL(deepLinkURL)
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
