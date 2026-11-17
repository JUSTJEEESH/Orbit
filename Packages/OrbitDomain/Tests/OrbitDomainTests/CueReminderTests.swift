import Foundation
import Testing
@testable import OrbitDomain

@Suite("Place and person reminders")
struct CueReminderTests {
    private let memoryID = UUID()

    private func only(_ text: String) -> CueHint? {
        let cues = CueParser.cues(in: text, memoryID: memoryID)
        return cues.count == 1 ? cues[0] : nil
    }

    @Test(arguments: [
        ("Remind me at Mom's to grab the ladder", "Mom's", "grab the ladder"),
        ("remind me to buy batteries when I get to Costco", "Costco", "buy batteries"),
        ("When I get to the office, print the contract.", "the office", "print the contract"),
        ("Next time I'm at Target, I need to get a shower curtain", "Target", "get a shower curtain"),
    ])
    func readsPlaceCues(text: String, place: String, action: String) throws {
        let cue = try #require(only(text))
        #expect(cue.target == .place(place))
        #expect(cue.action == action)
    }

    @Test(arguments: [
        ("Next time I see Alex, ask about the trip", "Alex", "ask about the trip"),
        ("remind me to return the drill next time I see my dad", "Dad", "return the drill"),
        ("Remind me when I see Priya to give her the book", "Priya", "give her the book"),
        ("when I'm with Jordan, ask about the job", "Jordan", "ask about the job"),
    ])
    func readsPersonCues(text: String, person: String, action: String) throws {
        let cue = try #require(only(text))
        #expect(cue.target == .person(person))
        #expect(cue.action == action)
    }

    @Test(arguments: ["remind me at 5pm to call the bank", "remind me at noon to eat", "Alex is coming over tonight"])
    func ignoresTimesAndPlainMentions(text: String) {
        #expect(CueParser.cues(in: text, memoryID: memoryID).isEmpty)
    }

    @Test func idsAreStableAcrossRuns() {
        let first = CueParser.cues(in: "Next time I see Alex, ask about the trip", memoryID: memoryID)
        let second = CueParser.cues(in: "Next time I see Alex, ask about the trip", memoryID: memoryID)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(StableUUID.make(from: "a") != StableUUID.make(from: "b"))
    }

    @Test func keptCueLeavesSuggestionsAndPlaceNeedsLocation() async throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let memory = Memory(content: .text("Remind me at Mom's to grab the ladder"), createdAt: now, updatedAt: now)
        let tasks = InMemoryTaskRepository()
        let list = ListCueSuggestionsUseCase(memories: InMemoryMemoryRepository(seed: [memory]), tasks: tasks)
        let keep = KeepCueReminderUseCase(tasks: tasks, clock: FixedClock(now))

        let suggestion = try #require(try await list().first)
        await #expect(throws: KeepCueReminderUseCase.KeepError.self) {
            try await keep(suggestion)
        }

        let moms = PlaceCue(name: "Mom's", latitude: 30.1, longitude: -97.7)
        let task = try await keep(suggestion, place: moms)
        #expect(task.title == "Grab the ladder")
        #expect(task.cue == .place(moms))
        #expect(task.linkedMemoryID == memory.id)
        #expect(try await list().isEmpty)
    }

    @Test func cueSentenceIsNotAlsoAPlainTaskSuggestion() async throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var memory = Memory(content: .text("remind me to buy batteries when I get to Costco"), createdAt: now, updatedAt: now)
        memory.ai.signals = ExtractedSignals(taskHints: [
            TaskHint(phrase: "buy batteries when I get to Costco", rawText: "remind me to buy batteries when I get to Costco")
        ])
        let suggestions = try await ListTaskSuggestionsUseCase(
            memories: InMemoryMemoryRepository(seed: [memory]),
            tasks: InMemoryTaskRepository()
        )()
        #expect(suggestions.isEmpty)
    }
}
