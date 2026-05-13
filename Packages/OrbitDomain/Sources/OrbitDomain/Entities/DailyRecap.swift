import Foundation

/// A reflective, AI-generated summary of one day's captures. Designed to
/// feel like a closing-the-day journal entry rather than a dashboard
/// readout — short, calm, in second person.
public struct DailyRecap: Sendable, Equatable, Hashable {
    /// The day this recap covers (start-of-day in the user's calendar).
    public let date: Date

    /// One-paragraph reflective summary, max ~3 sentences. Reads as if a
    /// thoughtful assistant noticed your day and reflected it back.
    public let narrative: String

    /// 1-5 highlight memory IDs the user most likely wants to revisit,
    /// in display order. Resolved against the repository at render time.
    public let highlightIDs: [UUID]

    /// Aggregate counts so the recap can show stats without a second
    /// query. Captures here are the *count of memories* the day produced.
    public let captureCount: Int

    /// Surface-level mood label the AI surfaced from the day's content
    /// (e.g. "focused", "scattered", "calm"). One word, lowercase. Empty
    /// when the AI couldn't pick something with confidence.
    public let mood: String?

    public let generatedAt: Date

    public init(
        date: Date,
        narrative: String,
        highlightIDs: [UUID],
        captureCount: Int,
        mood: String?,
        generatedAt: Date
    ) {
        self.date = date
        self.narrative = narrative
        self.highlightIDs = highlightIDs
        self.captureCount = captureCount
        self.mood = mood
        self.generatedAt = generatedAt
    }
}
