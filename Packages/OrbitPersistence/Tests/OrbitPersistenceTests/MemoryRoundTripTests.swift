import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence
import OrbitDomain

@Suite("SwiftData round-trip", .serialized)
struct MemoryRoundTripTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeContainer(mode: .inMemory)
    }

    @Test func textMemorySurvivesRoundTrip() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)
        let memory = Memory(
            content: .text("Renew passport before July"),
            createdAt: .init(timeIntervalSince1970: 100),
            updatedAt: .init(timeIntervalSince1970: 100),
            tags: [Tag(name: "travel")]
        )

        try await repo.save(memory)
        let fetched = try await repo.memory(with: memory.id)

        #expect(fetched != nil)
        #expect(fetched?.content == .text("Renew passport before July"))
        #expect(fetched?.tags.map(\.name) == ["travel"])
    }

    @Test func linkMemorySurvivesRoundTrip() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)
        let url = URL(string: "https://orbit.app")!
        let memory = Memory(
            content: .link(url: url, title: "Orbit", summary: "AI second brain"),
            createdAt: .now,
            updatedAt: .now
        )

        try await repo.save(memory)
        let fetched = try await repo.memory(with: memory.id)

        guard case .link(let fetchedURL, let title, let summary) = fetched?.content else {
            Issue.record("Expected link content")
            return
        }
        #expect(fetchedURL == url)
        #expect(title == "Orbit")
        #expect(summary == "AI second brain")
    }

    @Test func listAppliesFilterAndSort() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)

        let older = Memory(content: .text("older"),
                           createdAt: Date(timeIntervalSince1970: 100),
                           updatedAt: Date(timeIntervalSince1970: 100))
        let newer = Memory(content: .text("newer"),
                           createdAt: Date(timeIntervalSince1970: 200),
                           updatedAt: Date(timeIntervalSince1970: 200))
        try await repo.save(older)
        try await repo.save(newer)

        let newestFirst = try await repo.list(filter: .all)
        #expect(newestFirst.map(\.id) == [newer.id, older.id])

        let oldestFirst = try await repo.list(filter: MemoryFilter(sort: .oldestFirst))
        #expect(oldestFirst.map(\.id) == [older.id, newer.id])
    }

    @Test func deletingRemovesFromStore() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)
        let memory = Memory(content: .text("temp"), createdAt: .now, updatedAt: .now)
        try await repo.save(memory)

        try await repo.delete(id: memory.id)
        let fetched = try await repo.memory(with: memory.id)
        #expect(fetched == nil)
    }

    @Test func tagsDedupeAcrossMemories() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)
        let tag = Tag(name: "travel")

        try await repo.save(Memory(content: .text("a"), createdAt: .now, updatedAt: .now, tags: [tag]))
        try await repo.save(Memory(content: .text("b"), createdAt: .now, updatedAt: .now, tags: [Tag(name: "travel")]))

        // Inspect storage directly: only one TagEntity for "travel" should exist.
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TagEntity>(predicate: #Predicate { $0.name == "travel" })
        let tags = try context.fetch(descriptor)
        #expect(tags.count == 1)
    }

    @Test func queryMatchesText() async throws {
        let container = try makeContainer()
        let repo = SwiftDataMemoryRepository(modelContainer: container)
        try await repo.save(Memory(content: .text("buy sourdough starter"), createdAt: .now, updatedAt: .now))
        try await repo.save(Memory(content: .text("call mom"), createdAt: .now, updatedAt: .now))

        let hits = try await repo.list(filter: MemoryFilter(query: "sourdough"))
        #expect(hits.count == 1)
        #expect(hits.first?.content == .text("buy sourdough starter"))
    }
}
