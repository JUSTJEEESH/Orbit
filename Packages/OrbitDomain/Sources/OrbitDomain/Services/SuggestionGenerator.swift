import Foundation

/// Produces "you might want to revisit" surfaces from the user's memories.
/// The engine implementation (cosine similarity + entity overlap + recency
/// decay) lives in OrbitAI; this protocol keeps the domain layer pure.
public protocol SuggestionGenerator: Sendable {
    /// Home-tab surface. Picks a deterministic memory-of-the-day anchor
    /// from the eligible window and returns it bundled with its top-ranked
    /// related memories. Returns `nil` when there's not enough corpus to
    /// land an honest result; the UI hides the section in that case.
    func suggestions(from memories: [Memory], now: Date) async -> MemorySuggestionFeed?

    /// Memory-Detail surface. Caller supplies the anchor explicitly (the
    /// memory currently on screen); returns the top-ranked memories that
    /// connect to it. Same-day candidates allowed — when the user is
    /// staring at a specific memory, "what else from that day connects to
    /// this" is a legitimate question. Empty array when nothing scores
    /// above the relevance floor.
    func relatedMemories(anchor: Memory, from memories: [Memory], now: Date) async -> [MemorySuggestionFeed.Related]
}
