import Foundation

/// "Where's my passport?" → the latest memory that says where it is.
/// Reads memory text directly, so notes saved before this feature existed
/// are found too. Things move, so the most recent placement wins.
public struct FindPlacementUseCase: Sendable {
    public struct Found: Sendable, Equatable {
        public let placement: ItemPlacement
        public let memory: Memory
    }

    private let memories: any MemoryRepository

    public init(memories: any MemoryRepository) {
        self.memories = memories
    }

    /// - Parameter question: a where-is question ("Where did I put the
    ///   spare keys?") or just the item ("spare keys").
    /// - Returns: nil when it isn't a where-is question or nothing matches.
    public func callAsFunction(question: String) async throws -> Found? {
        let item = PlacementParser.item(inQuestion: question)
        return try await find(item: item)
    }

    /// Looks up an item named directly, as Siri passes it ("passport").
    public func callAsFunction(item: String) async throws -> Found? {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await find(item: trimmed.isEmpty ? nil : trimmed)
    }

    private func find(item: String?) async throws -> Found? {
        guard let item else { return nil }
        // Newest first; excludes Recently Deleted and sealed time capsules.
        let candidates = try await memories.list(filter: MemoryFilter(sort: .newestFirst))
        for memory in candidates {
            let placement = PlacementParser.placements(in: memory.analyzableText)
                .last { PlacementParser.matches(placementItem: $0.item, question: item) }
            if let placement {
                return Found(placement: placement, memory: memory)
            }
        }
        return nil
    }
}
