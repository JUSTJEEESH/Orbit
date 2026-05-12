import Foundation

public struct SearchMemoriesUseCase: Sendable {
    public struct Result: Identifiable, Sendable, Hashable {
        public let memory: Memory
        public let score: Double
        public let highlight: String?
        public var id: UUID { memory.id }

        public init(memory: Memory, score: Double, highlight: String?) {
            self.memory = memory
            self.score = score
            self.highlight = highlight
        }
    }

    private let search: any SearchService
    private let memories: any MemoryRepository

    public init(search: any SearchService, memories: any MemoryRepository) {
        self.search = search
        self.memories = memories
    }

    public func callAsFunction(_ query: SearchQuery) async throws -> [Result] {
        let hits = try await search.search(query)
        var results: [Result] = []
        results.reserveCapacity(hits.count)
        // Search by id pulls full Memory records — including sealed ones,
        // since memory(with:) doesn't apply the filter. Drop them here so
        // sealed time capsules / letters stay invisible until they arrive.
        for hit in hits {
            if let memory = try await memories.memory(with: hit.memoryID), !memory.isSealed() {
                results.append(Result(memory: memory, score: hit.score, highlight: hit.highlight))
            }
        }
        return results
    }
}
