import Foundation
import Testing
@testable import OrbitDomain

@Suite("Where did I put it")
struct PlacementTests {
    @Test(arguments: [
        ("Passport is in the blue box, top shelf.", "Your passport is in the blue box, top shelf."),
        ("I put my passport in the blue box on the top shelf", "You put your passport in the blue box on the top shelf."),
        ("The spare keys are under the mat by the back door", "Your spare keys are under the mat by the back door."),
        ("I left my wallet at home before work", "You left your wallet at home."),
        ("I left my keys in the car, then went inside", "You left your keys in the car."),
        ("I think the passport is in the drawer", "Your passport is in the drawer."),
        ("My charger is on the desk in my office", "Your charger is on the desk in your office."),
    ])
    func readsPlacements(text: String, sentence: String) {
        #expect(PlacementParser.placements(in: text).map(\.sentence) == [sentence])
    }

    @Test(arguments: ["The meeting is in the morning", "It is in the works", "Moved on with my day"])
    func ignoresNonPlacements(text: String) {
        #expect(PlacementParser.placements(in: text).isEmpty)
    }

    @Test(arguments: [
        ("Where's my passport?", "passport"),
        ("where did I put the spare keys", "spare keys"),
        ("Where are my keys again?", "keys"),
        ("Where do I keep the tax folder?", "tax folder"),
    ])
    func readsQuestions(question: String, item: String) {
        #expect(PlacementParser.item(inQuestion: question) == item)
    }

    @Test(arguments: ["What's for dinner?", "Where is the meeting?", "Who did I see last week?"])
    func ignoresOtherQuestions(question: String) {
        #expect(PlacementParser.item(inQuestion: question) == nil)
    }

    @Test func matchingIsLooseOnPluralsAndQualifiers() {
        #expect(PlacementParser.matches(placementItem: "car keys", question: "keys"))
        #expect(PlacementParser.matches(placementItem: "keys", question: "key"))
        #expect(!PlacementParser.matches(placementItem: "passport", question: "keys"))
    }

    @Test func latestPlacementWins() async throws {
        let older = Memory(content: .text("Passport is in the desk drawer"),
                           createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 1_000))
        let newer = Memory(content: .text("Moved stuff today. Passport is in the blue box now? No — I put my passport in the safe"),
                           createdAt: Date(timeIntervalSince1970: 2_000), updatedAt: Date(timeIntervalSince1970: 2_000))
        let trashed = Memory(content: .text("Passport is in the car"),
                             createdAt: Date(timeIntervalSince1970: 3_000), updatedAt: Date(timeIntervalSince1970: 3_000),
                             deletedAt: Date(timeIntervalSince1970: 3_500))
        let find = FindPlacementUseCase(memories: InMemoryMemoryRepository(seed: [older, newer, trashed]))

        let found = try #require(try await find(question: "Where's my passport?"))
        #expect(found.memory.id == newer.id)
        #expect(found.placement.sentence == "You put your passport in the safe.")
        #expect(try await find(question: "What did I eat?") == nil)
        #expect(try await find(item: "passport")?.memory.id == newer.id)
    }
}
