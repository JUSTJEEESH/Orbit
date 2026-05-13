import Foundation

/// Produces a `MemorySuggestionFeed` from the user's memories. The engine
/// implementation (cosine similarity + entity overlap + recency decay) lives
/// in OrbitAI; this protocol keeps the domain layer pure.
///
/// Returning `nil` signals "no suggestion is appropriate right now" — the UI
/// hides the section rather than rendering a partial card.
public protocol SuggestionGenerator: Sendable {
    func suggestions(from memories: [Memory], now: Date) async -> MemorySuggestionFeed?
}
