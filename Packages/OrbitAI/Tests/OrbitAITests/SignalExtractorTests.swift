import Foundation
import Testing
import OrbitDomain
@testable import OrbitAI

@Suite("Signal extractor")
struct SignalExtractorTests {

    private func memory(text: String) -> Memory {
        Memory(
            content: .text(text),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func detectsTaskHintsFromCommonPhrasing() {
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(
            text: "I should call mom tomorrow. Also remember to buy groceries."
        ))
        let phrases = result.taskHints.map(\.phrase.lowercased())
        #expect(phrases.contains { $0.contains("call mom") })
        #expect(phrases.contains { $0.contains("buy groceries") })
    }

    @Test func dedupesIdenticalTaskHints() {
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(
            text: "I should call mom. Remember to call mom."
        ))
        let phrases = result.taskHints.map(\.phrase.lowercased())
        let callMoms = phrases.filter { $0.contains("call mom") }
        #expect(callMoms.count == 1)
    }

    @Test func detectsHabitVerbs() {
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(
            text: "Ran 5k this morning and meditated for 10 minutes after."
        ))
        let habits = result.habitMentions.map(\.habit)
        #expect(habits.contains("running"))
        #expect(habits.contains("meditation"))
    }

    @Test func ignoresNonHabitWordsThatLookSimilar() {
        // "errand" should not trigger "ran".
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(text: "Quick errand at the post office."))
        #expect(!result.habitMentions.contains { $0.habit == "running" })
    }

    @Test func detectsReadingItems() {
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(
            text: "I want to read Pachinko by Min Jin Lee. Currently reading Dune."
        ))
        let titles = result.readingItems.map { $0.title?.lowercased() ?? "" }
        #expect(titles.contains { $0.contains("pachinko") })
        #expect(titles.contains { $0.contains("dune") })
    }

    @Test func linkMemoriesProduceImplicitReadingItems() {
        let extractor = SignalExtractor()
        let linkMemory = Memory(
            content: .link(
                url: URL(string: "https://example.com/article")!,
                title: "An article",
                summary: nil
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        let result = extractor.extract(from: linkMemory)
        #expect(result.readingItems.contains { $0.title == "An article" })
        #expect(result.readingItems.contains { $0.status == .wantToRead })
    }

    @Test func emptyMemoryReturnsEmptySignals() {
        let extractor = SignalExtractor()
        let result = extractor.extract(from: memory(text: ""))
        #expect(result.isEmpty)
    }
}
