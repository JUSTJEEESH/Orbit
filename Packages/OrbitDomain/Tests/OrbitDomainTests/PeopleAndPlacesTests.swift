import Foundation
import Testing
@testable import OrbitDomain

@Suite("People and places")
struct PeopleAndPlacesTests {
    private func memory(people: [String] = [], places: [String] = [], at seconds: TimeInterval,
                        content: MemoryContent = .text("note")) -> Memory {
        Memory(
            content: content,
            createdAt: Date(timeIntervalSince1970: seconds),
            updatedAt: Date(timeIntervalSince1970: seconds),
            ai: MemoryAIMetadata(status: .complete, summary: nil, category: nil, priority: .normal,
                                 extractedDates: [], extractedPeople: people, extractedLocations: places)
        )
    }

    @Test func groupsSpellingsAndRanksByMemoryCount() {
        let memories = [
            memory(people: ["Pamela", "Sam"], at: 1),
            memory(people: ["pamela "], at: 2),
            memory(people: ["Pamela"], at: 3),
        ]
        let people = ListMentionedEntitiesUseCase.summarize(memories, kind: .person, limit: nil)
        #expect(people.map(\.name) == ["Pamela", "Sam"])
        #expect(people.first?.memoryCount == 3)
        #expect(people.first?.lastMentioned == Date(timeIntervalSince1970: 3))
    }

    @Test func lastContactIsTheLatestTimeTogetherNotTheLatestMention() {
        let memories = [
            memory(people: ["Dad"], at: 1, content: .text("Called Dad about the roof")),
            memory(people: ["Dad"], at: 2, content: .text("Had lunch with my dad downtown")),
            memory(people: ["Dad"], at: 3, content: .text("Dad's birthday is in May")),
        ]
        let dad = ListMentionedEntitiesUseCase.summarize(memories, kind: .person, limit: nil).first
        #expect(dad?.lastMentioned == Date(timeIntervalSince1970: 3))
        #expect(dad?.lastContact == Date(timeIntervalSince1970: 2))
    }

    @Test func noContactWhenOnlyMentioned() {
        let memories = [memory(people: ["Sam"], at: 1, content: .text("Sam recommended this book"))]
        #expect(ListMentionedEntitiesUseCase.summarize(memories, kind: .person, limit: nil).first?.lastContact == nil)
    }

    @Test func placesIncludeSavedLocations() {
        let memories = [
            memory(places: ["Roatán"], at: 1),
            memory(at: 2, content: .location(name: "Roatán", latitude: 16.3, longitude: -86.5)),
        ]
        let places = ListMentionedEntitiesUseCase.summarize(memories, kind: .place, limit: nil)
        #expect(places.count == 1)
        #expect(places.first?.memoryCount == 2)
    }

    @Test func listsMemoriesMentioningAnEntityNewestFirst() async throws {
        let older = memory(people: ["Pamela"], at: 1)
        let newer = memory(people: ["PAMELA"], at: 2)
        let unrelated = memory(people: ["Sam"], at: 3)
        let repo = InMemoryMemoryRepository(seed: [older, newer, unrelated])
        let pamela = try #require(try await ListMentionedEntitiesUseCase(repository: repo)(kind: .person).first { $0.name.lowercased() == "pamela" })

        let mentions = try await ListMemoriesMentioningUseCase(repository: repo)(pamela)
        #expect(mentions.map(\.id) == [newer.id, older.id])
    }
}
