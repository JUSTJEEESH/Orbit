import Foundation
import NaturalLanguage

/// Generates sentence-level embeddings via Apple's `NLEmbedding`. Used for
/// semantic search ranking. Falls back to an empty vector when the
/// language-specific embedding isn't installed on the device — callers
/// should treat empty results as "lexical-only ranking".
///
/// The underlying `NLEmbedding` model load is the single most expensive
/// thing that used to happen during cold launch (100–300ms on real
/// hardware) — so this actor defers it until the first `embed` call.
/// Search and AI enrichment both arrive on background paths, never on
/// the cold-launch critical path, which is why the deferral is safe.
public actor EmbeddingService {
    private let language: NLLanguage
    private var sentence: NLEmbedding?
    private var didLoad = false

    public init(language: NLLanguage = .english) {
        self.language = language
    }

    public func embed(_ text: String) -> [Float] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        loadIfNeeded()
        guard let sentence else { return [] }
        guard let vector = sentence.vector(for: trimmed)
                ?? sentence.vector(for: trimmed.lowercased()) else {
            return []
        }
        return vector.map { Float($0) }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        sentence = NLEmbedding.sentenceEmbedding(for: language)
    }
}
