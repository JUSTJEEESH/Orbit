import Foundation
import Testing
@testable import OrbitAI

@Suite("Search scoring")
struct SearchScoringTests {

    @Test func cosineOfIdenticalVectorsIsOne() {
        let vector: [Float] = [0.1, 0.2, 0.3, 0.4]
        let score = SearchScoring.cosineSimilarity(vector, vector)
        #expect(score > 0.999)
    }

    @Test func cosineOfOppositeVectorsIsZero() {
        let lhs: [Float] = [1, 0, 0]
        let rhs: [Float] = [-1, 0, 0]
        let score = SearchScoring.cosineSimilarity(lhs, rhs)
        #expect(score == 0)
    }

    @Test func cosineHandlesEmptyVectors() {
        #expect(SearchScoring.cosineSimilarity([], [1, 2, 3]) == 0)
        #expect(SearchScoring.cosineSimilarity([1, 2, 3], []) == 0)
    }

    @Test func lexicalScoreRewardsRecallAndEarliness() {
        let early = SearchScoring.lexicalScore(
            query: "passport renew",
            in: "passport renew before July trip"
        )
        let late = SearchScoring.lexicalScore(
            query: "passport renew",
            in: String(repeating: "lorem ipsum ", count: 30) + " passport renew"
        )
        #expect(early > late)
        #expect(early > 0.5)
    }

    @Test func lexicalScoreIsZeroOnNoOverlap() {
        let score = SearchScoring.lexicalScore(query: "guatemala", in: "buy milk")
        #expect(score == 0)
    }

    @Test func combinedFallsBackToLexicalAlone() {
        let combined = SearchScoring.combined(lexical: 0.8, semantic: 0)
        #expect(combined > 0)
        #expect(combined < 0.8)
    }
}
