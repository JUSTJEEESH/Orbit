import Foundation

/// Promotes a reading item through its lifecycle — wantToRead →
/// currentlyReading → finished — by patching the source memory's signals
/// and saving it back. UI calls this via swipe / tap; no copy of the
/// reading item lives outside the memory.
public struct UpdateReadingItemStatusUseCase: Sendable {
    private let memories: any MemoryRepository
    private let clock: any OrbitClock

    public init(memories: any MemoryRepository, clock: any OrbitClock) {
        self.memories = memories
        self.clock = clock
    }

    public func callAsFunction(
        itemID: UUID,
        in memoryID: UUID,
        newStatus: ReadingItem.Status
    ) async throws {
        guard var memory = try await memories.memory(with: memoryID) else { return }
        guard let idx = memory.ai.signals.readingItems.firstIndex(where: { $0.id == itemID }) else { return }
        memory.ai.signals.readingItems[idx].status = newStatus
        memory.updatedAt = clock.now()
        try await memories.update(memory)
    }
}
