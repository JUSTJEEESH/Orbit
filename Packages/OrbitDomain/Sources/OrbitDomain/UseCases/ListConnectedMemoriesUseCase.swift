import Foundation

/// Returns the memories most-related to a specific anchor memory — used by
/// the "Connected memories" surface on Memory Detail. The anchor is the
/// memory the user is currently viewing; the wider corpus is what we rank
/// candidates from.
///
/// Returns an empty array (not an error) when the anchor doesn't exist or
/// when nothing scores above the relevance floor. The Detail view treats
/// empty-array and section-hidden as the same outcome.
public struct ListConnectedMemoriesUseCase: Sendable {
    private let memories: any MemoryRepository
    private let generator: any SuggestionGenerator
    private let dismissalStore: any SuggestionDismissalStore
    private let clock: any OrbitClock

    public init(
        memories: any MemoryRepository,
        generator: any SuggestionGenerator,
        dismissalStore: any SuggestionDismissalStore,
        clock: any OrbitClock
    ) {
        self.memories = memories
        self.generator = generator
        self.dismissalStore = dismissalStore
        self.clock = clock
    }

    public func callAsFunction(anchorID: UUID) async throws -> [MemorySuggestionFeed.Related] {
        let now = clock.now()
        let all = try await memories.list(filter: .all)
        guard let anchor = all.first(where: { $0.id == anchorID }) else { return [] }
        let dismissed = dismissalStore.dismissedIDs(at: now)
        return await generator.relatedMemories(
            anchor: anchor,
            from: all,
            dismissedIDs: dismissed,
            now: now
        )
    }
}
