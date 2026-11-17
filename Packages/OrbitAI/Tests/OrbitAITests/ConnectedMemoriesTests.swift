import Foundation
import OrbitDomain
import Testing
@testable import OrbitAI

@Suite("Connected memories")
struct ConnectedMemoriesTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    /// The same vector for every memory: the worst case, where embeddings
    /// say everything is alike (what short "remind me…" notes looked like).
    private let sameEmbedding: [Float] = [0.3, 0.5, 0.2, 0.7]

    private func memory(
        _ text: String,
        people: [String] = [],
        places: [String] = [],
        daysAgo: Double = 0
    ) -> Memory {
        let created = now.addingTimeInterval(-daysAgo * 86_400)
        var ai = MemoryAIMetadata.pending
        ai.extractedPeople = people
        ai.extractedLocations = places
        return Memory(content: .text(text), createdAt: created, updatedAt: created, ai: ai, embedding: sameEmbedding)
    }

    // MARK: - Evidence

    @Test func reminderPhrasingIsNotAConnection() {
        let ladder = memory("Remind me to grab the ladder at mom's", people: ["Mom"])
        let speaker = memory("Remind me to get the speaker from Scott", people: ["Scott"])
        #expect(!ConnectionEvidence(ladder, speaker).isConnected)
    }

    @Test func sharedPersonConnects() {
        let ladder = memory("Remind me to grab the ladder at mom's", people: ["Mom"])
        let dinner = memory("Dinner with Mom on Sunday", people: ["Mom"])
        let evidence = ConnectionEvidence(ladder, dinner)
        #expect(evidence.sharedEntities == ["mom"])
        #expect(evidence.isConnected)
    }

    @Test func sharedSubjectWordConnectsAcrossPlurals() {
        let lhs = memory("Ladder is in the garage")
        let rhs = memory("Return the ladders to Dave")
        #expect(ConnectionEvidence(lhs, rhs).sharedWords == ["ladder"])
    }

    @Test func possessiveNamesMatchPlainNames() {
        #expect(ConnectionEvidence.normalizeName("Mom's") == "mom")
        #expect(ConnectionEvidence.normalizeName(" Scott’s ") == "scott")
        #expect(ConnectionEvidence.subjectWords(in: "at Mom's house") == ["mom"])
    }

    @Test func fillerTimesAndContractionsAreIgnored() {
        let words = ConnectionEvidence.subjectWords(in: "Don't forget: tomorrow I need to call and get the thing")
        #expect(words.isEmpty)
    }

    @Test func ignoredWordListHasNoDuplicates() {
        // A Set literal with a duplicate traps at runtime; this keeps it
        // honest as the list grows.
        #expect(ConnectionEvidence.ignoredWords.count > 200)
    }

    // MARK: - Engine

    @Test func unrelatedRemindersDoNotConnectEvenWithIdenticalEmbeddings() async {
        let ladder = memory("Remind me to grab the ladder at mom's", people: ["Mom"])
        let others = [
            memory("Remind me to get the speaker from Scott", people: ["Scott"]),
            memory("Remind me to pay the water bill"),
            memory("Remind me to pick up dry cleaning"),
        ]
        let related = await SuggestionEngine().relatedMemories(
            anchor: ladder, from: [ladder] + others, dismissedIDs: [], now: now
        )
        #expect(related.isEmpty)
    }

    @Test func realConnectionsStillShowStrongestFirst() async {
        let ladder = memory("Remind me to grab the ladder at mom's", people: ["Mom"])
        let momAndLadder = memory("Mom wants the ladder back before the gutters", people: ["Mom"], daysAgo: 3)
        let momOnly = memory("Mom's birthday dinner", people: ["Mom"], daysAgo: 1)
        let unrelated = memory("Remind me to get the speaker from Scott", people: ["Scott"])
        let related = await SuggestionEngine().relatedMemories(
            anchor: ladder, from: [ladder, momAndLadder, momOnly, unrelated], dismissedIDs: [], now: now
        )
        #expect(related.map(\.memory.id) == [momAndLadder.id, momOnly.id])
    }
}
