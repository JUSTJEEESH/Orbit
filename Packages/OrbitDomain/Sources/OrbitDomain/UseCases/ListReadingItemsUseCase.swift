import Foundation

/// A single reading item lifted onto the smart-folder UI, carrying the
/// source memory's id + timestamp so the view can render context + jump
/// back to the originating capture.
public struct ReadingListEntry: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let memoryID: UUID
    public let memoryCreatedAt: Date
    public let title: String?
    public let url: URL?
    public let status: ReadingItem.Status

    public init(
        id: UUID,
        memoryID: UUID,
        memoryCreatedAt: Date,
        title: String?,
        url: URL?,
        status: ReadingItem.Status
    ) {
        self.id = id
        self.memoryID = memoryID
        self.memoryCreatedAt = memoryCreatedAt
        self.title = title
        self.url = url
        self.status = status
    }
}

/// Flattens every memory's `signals.readingItems` into a single list the
/// Reading view groups by status. Sealed memories are filtered out via the
/// repo's default filter, so scheduled letters can't leak a reading list
/// the user hasn't seen yet.
public struct ListReadingItemsUseCase: Sendable {
    private let memories: any MemoryRepository

    public init(memories: any MemoryRepository) {
        self.memories = memories
    }

    public func callAsFunction() async throws -> [ReadingListEntry] {
        let all = try await memories.list(filter: .all)
        let entries: [ReadingListEntry] = all.flatMap { memory in
            memory.ai.signals.readingItems.map { item in
                ReadingListEntry(
                    id: item.id,
                    memoryID: memory.id,
                    memoryCreatedAt: memory.createdAt,
                    title: item.title,
                    url: item.url,
                    status: item.status
                )
            }
        }
        // Newest-first by source-memory timestamp keeps "I just added this"
        // visible at the top of every section.
        return entries.sorted { $0.memoryCreatedAt > $1.memoryCreatedAt }
    }
}
