import Foundation

/// A single observation surfaced to the user — a pattern that emerged from
/// their captured memories, expressed in one short sentence.
///
/// Insights are *generated*, not stored. The engine recomputes them from the
/// current memory list; the persistence layer only holds the user's
/// dismissals (see `InsightDismissalStore`).
public struct SmartInsight: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: Kind
    /// The eyebrow word — usually the entity, category, or day name. Rendered
    /// in the theme accent so the user's eye lands here first.
    public let headline: String
    /// One short sentence that completes the observation.
    public let body: String
    /// Longer detail rendered on the patterns screen. Optional — falls back
    /// to `body` when omitted.
    public let detail: String?
    /// The source memories that justify this insight. Tapping the insight on
    /// the patterns screen opens a filtered list of these.
    public let memoryIDs: [UUID]
    /// Up to 8 weekly counts (oldest → newest) used to render a small bar
    /// chart on the patterns screen. Empty when the insight has no
    /// time-series shape (e.g. day-of-week).
    public let sparkline: [Int]
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        headline: String,
        body: String,
        detail: String? = nil,
        memoryIDs: [UUID],
        sparkline: [Int] = [],
        generatedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.body = body
        self.detail = detail
        self.memoryIDs = memoryIDs
        self.sparkline = sparkline
        self.generatedAt = generatedAt
    }

    public enum Kind: String, Sendable, CaseIterable, Hashable {
        /// A specific person or place keeps showing up.
        case topEntity
        /// A category is surging this week.
        case trendingCategory
        /// One weekday is over-represented in capture timestamps.
        case dayOfWeek
        /// Total captures this week vs last week diverge meaningfully.
        case weeklyVolume

        public var label: String {
            switch self {
            case .topEntity:        return "On your mind"
            case .trendingCategory: return "Trending"
            case .dayOfWeek:        return "Rhythm"
            case .weeklyVolume:     return "Pace"
            }
        }
    }
}

/// Stores per-kind dismissals so the user can hide insight classes they
/// don't find useful. Dismissals expire after a window so the surface
/// re-introduces itself once the underlying pattern is meaningfully
/// different.
public protocol InsightDismissalStore: Sendable {
    func isDismissed(_ kind: SmartInsight.Kind, now: Date) -> Bool
    func dismiss(_ kind: SmartInsight.Kind, until: Date)
    func reset()
}
