import WidgetKit
import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit
import OrbitPersistence

/// Surfaces the SuggestionEngine's memory-of-the-day anchor on the home
/// screen. Tapping it deep-links to that memory in the Timeline tab,
/// matching the in-app "Worth revisiting" section.
///
/// We deliberately *inline* the day-seeded anchor pick instead of
/// importing OrbitAI — widget targets have a much tighter compute /
/// link-time budget, and the anchor algorithm is ~20 lines. The
/// `daySeed`, age window, and letter-exclusion rules are copy-pasted
/// from `SuggestionEngine.pickAnchor` so the home-screen pick is the
/// same memory the app shows. If the in-app engine changes, this widget
/// needs to be kept in sync.
struct WorthRevisitingWidget: Widget {
    let kind: String = "com.orbit.app.widgets.worth-revisiting"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorthRevisitingProvider()) { entry in
            WorthRevisitingWidgetView(entry: entry)
                .containerBackground(OrbitColor.background, for: .widget)
        }
        .configurationDisplayName("Worth Revisiting")
        .description("A memory from your past, surfaced quietly each day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorthRevisitingEntry: TimelineEntry {
    let date: Date
    let memory: Memory?
}

struct WorthRevisitingProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorthRevisitingEntry {
        WorthRevisitingEntry(date: Date(), memory: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorthRevisitingEntry) -> Void) {
        let callback = SendableCompletion(completion)
        Task {
            let memory = await pickAnchor(now: Date())
            callback.invoke(WorthRevisitingEntry(date: Date(), memory: memory))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorthRevisitingEntry>) -> Void) {
        let callback = SendableCompletion(completion)
        Task {
            let now = Date()
            let memory = await pickAnchor(now: now)
            let entry = WorthRevisitingEntry(date: now, memory: memory)
            // Anchor changes at the calendar-day boundary. Schedule the
            // next refresh for the start of tomorrow so the widget
            // rotates without waiting on the host app's
            // WidgetCenter.reloadAllTimelines().
            let nextRefresh = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            )
            callback.invoke(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    // MARK: - Anchor pick (mirrors SuggestionEngine.pickAnchor)

    /// Anchor must be at least this old.
    private let anchorMinAgeDays: Int = 7
    /// Anchor must be no older than this.
    private let anchorMaxAgeDays: Int = 60

    private func pickAnchor(now: Date) async -> Memory? {
        let calendar = Calendar.current
        guard
            let oldestEligible = calendar.date(byAdding: .day, value: -anchorMaxAgeDays, to: now),
            let newestEligible = calendar.date(byAdding: .day, value: -anchorMinAgeDays, to: now)
        else { return nil }

        let all = await fetchAll()
        let eligible = all
            .filter { !$0.isSealed(at: now) }
            .filter { $0.createdAt >= oldestEligible && $0.createdAt <= newestEligible }
            .filter { !$0.isLetter }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        guard !eligible.isEmpty else { return nil }
        let seed = daySeed(for: now, calendar: calendar)
        let index = seed % UInt64(eligible.count)
        return eligible[Int(index)]
    }

    /// Mixes the calendar day into a 64-bit seed using the SplitMix64
    /// finalizer. Same algorithm as SuggestionEngine.daySeed so the
    /// widget and the in-app section land on the same memory.
    private func daySeed(for now: Date, calendar: Calendar) -> UInt64 {
        let comps = calendar.dateComponents([.year, .month, .day], from: now)
        let year = UInt64(comps.year ?? 2026)
        let month = UInt64(comps.month ?? 1)
        let day = UInt64(comps.day ?? 1)
        var seed = year &* 1_000_000 &+ month &* 1_000 &+ day
        seed ^= seed >> 33
        seed &*= 0xff51afd7ed558ccd
        seed ^= seed >> 33
        return seed
    }

    private func fetchAll() async -> [Memory] {
        // Surface the App Group resolution state to Console so we can tell
        // the difference between "entitlement missing" (factory falls back
        // to a per-process store the host app can't see) and "container
        // opens but is genuinely empty."
        let storeURL = ModelContainerFactory.appGroupStoreURL(for: "group.com.joshgreen.orbit")
        if storeURL == nil {
            OrbitLog.app.error("Worth-revisiting widget: App Group container unresolved. Entitlement missing or sandbox blocked.")
        }
        do {
            let container = try ModelContainerFactory.makeContainer(
                mode: .appGroup(identifier: "group.com.joshgreen.orbit")
            )
            let repo = SwiftDataMemoryRepository(modelContainer: container)
            let memories = try await repo.list(filter: .all)
            OrbitLog.app.notice("Worth-revisiting widget: fetched \(memories.count, privacy: .public) memories; storeURL=\(storeURL?.path ?? "<nil>", privacy: .public).")
            return memories
        } catch {
            OrbitLog.app.error("Worth-revisiting widget: fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}

struct WorthRevisitingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WorthRevisitingEntry

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
        .widgetURL(deepLinkURL)
    }

    // MARK: - Pieces

    /// Editorial eyebrow: small accented dot + tracked uppercase label.
    /// Feels like a magazine kicker rather than a generic widget header,
    /// matching the in-app OrbitEyebrow visual.
    private var eyebrow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(OrbitColor.accent)
                .frame(width: 6, height: 6)
            Text("WORTH REVISITING")
                .font(OrbitTypography.caption)
                .tracking(0.9)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    /// Right-sized per widget family. systemSmall is ~160pt wide, so
    /// `.body` overflows and clips; footnote keeps 4-5 lines readable
    /// while leaving room for the eyebrow and footer.
    private var headlineFont: Font {
        switch family {
        case .systemSmall: return OrbitTypography.footnote
        default: return OrbitTypography.callout
        }
    }

    private var headlineLineLimit: Int {
        switch family {
        case .systemSmall: return 5
        default: return 4
        }
    }

    private func footer(_ memory: Memory) -> some View {
        HStack(spacing: 6) {
            // Category chip eats horizontal space — only show on medium+
            // where there's room for it alongside the date.
            if family != .systemSmall,
               let category = memory.ai.category, !category.isEmpty {
                chip(category)
            }
            Spacer(minLength: 0)
            Text(dateText(for: memory.createdAt))
                .font(OrbitTypography.caption)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }

    /// Small widget gets the abbreviated absolute date (`Apr 22`) — saves
    /// horizontal space and reads cleaner at small sizes than a relative
    /// phrase like "3 weeks ago." Medium gets the relative phrase which
    /// is friendlier when there's room.
    private func dateText(for date: Date) -> String {
        switch family {
        case .systemSmall:
            return date.formatted(.dateTime.month(.abbreviated).day())
        default:
            return date.formatted(.relative(presentation: .named))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: "sparkle")
                .scaledFont(size: 22, weight: .regular)
                .foregroundStyle(OrbitColor.textTertiary)
            Text("Nothing to revisit yet")
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
