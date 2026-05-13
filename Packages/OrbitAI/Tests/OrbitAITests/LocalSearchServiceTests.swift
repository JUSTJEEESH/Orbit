import Foundation
import Testing
@testable import OrbitAI
import OrbitDomain

@Suite("Local search service")
struct LocalSearchServiceTests {

    private func makeMemory(_ text: String, tags: [String] = []) -> Memory {
        Memory(
            content: .text(text),
            createdAt: Date(),
            updatedAt: Date(),
            tags: tags.map { Tag(name: $0) }
        )
    }

    @Test func returnsExactLexicalMatch() async throws {
        let target = makeMemory("Renew passport before the July Guatemala trip")
        let distractor = makeMemory("Pick up milk and eggs")
        let repo = InMemoryMemoryRepository(seed: [target, distractor])
        let service = LocalSearchService(memories: repo, embeddings: EmbeddingService())

        let hits = try await service.search(SearchQuery(text: "passport", limit: 10))
        #expect(hits.first?.memoryID == target.id)
    }

    @Test func returnsNothingForEmptyQuery() async throws {
        let memory = makeMemory("Anything")
        let repo = InMemoryMemoryRepository(seed: [memory])
        let service = LocalSearchService(memories: repo, embeddings: EmbeddingService())

        let hits = try await service.search(SearchQuery(text: "   ", limit: 10))
        #expect(hits.isEmpty)
    }

    @Test func filtersByKind() async throws {
        let note = makeMemory("travel itinerary for July")
        let link = Memory(
            content: .link(url: URL(string: "https://orbit.app/travel")!, title: "Travel plans", summary: nil),
            createdAt: Date(),
            updatedAt: Date()
        )
        let repo = InMemoryMemoryRepository(seed: [note, link])
        let service = LocalSearchService(memories: repo, embeddings: EmbeddingService())

        let hits = try await service.search(SearchQuery(text: "travel", kinds: [.link], limit: 10))
        #expect(hits.count == 1)
        #expect(hits.first?.memoryID == link.id)
    }
}
