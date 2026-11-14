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

    @Test func cosineOfOrthogonalVectorsIsZero() {
        // 1.x mapped this to 0.5, which let unrelated memories into results.
        #expect(SearchScoring.cosineSimilarity([1, 0, 0], [0, 1, 0]) == 0)
    }

    @Test func unrelatedMemoryIsNotRelevant() {
        // No shared words and only background-level embedding similarity.
        #expect(!SearchScoring.isRelevant(lexical: 0, semantic: 0.3))
        #expect(!SearchScoring.isRelevant(lexical: 0, semantic: 0))
    }

    @Test func stronglySimilarMeaningIsRelevantWithoutSharedWords() {
        #expect(SearchScoring.isRelevant(lexical: 0, semantic: 0.8))
    }

    @Test func anyLiteralMatchIsRelevant() {
        #expect(SearchScoring.isRelevant(lexical: 0.1, semantic: 0))
    }

    @Test func literalMatchesOutrankMeaningOnlyMatches() {
        let weakLiteral = SearchScoring.combined(lexical: 0.05, semantic: 0)
        let perfectMeaning = SearchScoring.combined(lexical: 0, semantic: 1)
        #expect(weakLiteral > perfectMeaning)
    }

    @Test func semanticSimilarityBreaksTiesBetweenLiteralMatches() {
        let plain = SearchScoring.combined(lexical: 0.6, semantic: 0.2)
        let alsoSimilar = SearchScoring.combined(lexical: 0.6, semantic: 0.9)
        #expect(alsoSimilar > plain)
    }
}
