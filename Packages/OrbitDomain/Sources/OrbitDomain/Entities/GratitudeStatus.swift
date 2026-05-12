import Foundation

/// Quick read on the user's gratitude practice. Surfaces on Home so the
/// "Three things you're grateful for" pill knows whether to invite the
/// user in, congratulate them on today's entry, or quietly stay hidden.
public struct GratitudeStatus: Sendable, Hashable {
    /// True when the user has already captured a gratitude entry today.
    public let hasEntryToday: Bool
    /// Consecutive days (anchored on today) the user has logged a gratitude.
    /// 0 means no streak yet. Premium streak design — never loud, never
    /// resets noisily.
    public let streak: Int
    /// Most recent entry across all time. Useful for "X days ago" copy.
    public let lastEntryAt: Date?
    public let generatedAt: Date

    public init(
        hasEntryToday: Bool,
        streak: Int,
        lastEntryAt: Date?,
        generatedAt: Date
    ) {
        self.hasEntryToday = hasEntryToday
        self.streak = streak
        self.lastEntryAt = lastEntryAt
        self.generatedAt = generatedAt
    }

    public static let empty = GratitudeStatus(
        hasEntryToday: false,
        streak: 0,
        lastEntryAt: nil,
        generatedAt: .init(timeIntervalSince1970: 0)
    )
}

/// The system tag every gratitude memory carries. Centralized here so the
/// capture path and the status-loader stay aligned without magic strings
/// scattered through feature code.
public enum GratitudeTag {
    public static let name = "gratitude"
}
