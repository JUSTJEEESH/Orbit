import Foundation

/// Builds the Home tab's "Worth revisiting" surface — a deterministic
/// memory-of-the-day plus the most-related memories from the wider corpus.
/// Returns `nil` when there's not enough history yet (the UI hides the
/// section in that case).
public struct ListSuggestionsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let generator: any SuggestionGenerator
    private let clock: any OrbitClock

    public init(
        memories: any MemoryRepository,
        generator: any SuggestionGenerator,
        clock: any OrbitClock
    ) {
        self.memories = memories
        self.generator = generator
        self.clock = clock
    }

    public func callAsFunction() async throws -> MemorySuggestionFeed? {
        let now = clock.now()
        let all = try await memories.list(filter: .all)
        return await generator.suggestions(from: all, now: now)
    }
}
