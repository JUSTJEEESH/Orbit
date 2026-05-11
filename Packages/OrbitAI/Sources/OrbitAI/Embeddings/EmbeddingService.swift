import Foundation
import NaturalLanguage

/// Generates sentence-level embeddings via Apple's `NLEmbedding`. Used for
/// semantic search ranking. Falls back to an empty vector when the
/// language-specific embedding isn't installed on the device — callers
/// should treat empty results as "lexical-only ranking".
public actor EmbeddingService {
    public let dimension: Int
    private let sentence: NLEmbedding?

    public init(language: NLLanguage = .english) {
        let embedding = NLEmbedding.sentenceEmbedding(for: language)
        self.sentence = embedding
        self.dimension = embedding?.dimension ?? 0
    }

    public func embed(_ text: String) -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let sentence else { return [] }
        guard let vector = sentence.vector(for: trimmed)
                ?? sentence.vector(for: trimmed.lowercased()) else {
            return []
        }
        return vector.map { Float($0) }
    }
}
