import Foundation

/// A "worth revisiting" surface for Home. An anchor memory (the memory-of-the-day,
/// chosen deterministically per day from the last 30 days) plus a ranked list of
/// related memories drawn from the user's wider corpus.
///
/// The engine that produces this feed lives in OrbitAI (`SuggestionEngine`).
/// The domain layer treats the result as best-effort — `nil` means the corpus
/// isn't ready (too small, too recent) and the UI should hide the surface.
public struct MemorySuggestionFeed: Sendable, Hashable {
    public let anchor: Memory
    public let related: [Related]
    public let generatedAt: Date

    public struct Related: Sendable, Hashable, Identifiable {
        public let memory: Memory
        /// Composite score (semantic + entity overlap + recency). Kept on the
        /// model so debug surfaces can render it; production UI ignores it.
        public let score: Double
        public var id: UUID { memory.id }

        public init(memory: Memory, score: Double) {
            self.memory = memory
            self.score = score
        }
    }

    public init(anchor: Memory, related: [Related], generatedAt: Date) {
        self.anchor = anchor
        self.related = related
        self.generatedAt = generatedAt
    }
}
