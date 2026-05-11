import Foundation
import OrbitDomain

/// In-memory hybrid search: lexical relevance + cosine over embeddings.
/// Suitable for the <5k-memory range Orbit targets at launch. We swap in a
/// disk-backed HNSW index when single-pass scoring stops being cheap.
public actor LocalSearchService: SearchService {
    private let memories: any MemoryRepository
    private let embeddings: EmbeddingService

    public init(memories: any MemoryRepository, embeddings: EmbeddingService) {
        self.memories = memories
        self.embeddings = embeddings
    }

    public func search(_ query: SearchQuery) async throws -> [SearchHit] {
        let text = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        let queryVector = await embeddings.embed(text)

        let candidates = try await memories.list(
            filter: MemoryFilter(
                kinds: query.kinds,
                dateRange: query.dateRange,
                sort: .newestFirst
            )
        )

        struct Scored {
            let memory: Memory
            let score: Double
            let highlight: String?
        }

        var scored: [Scored] = []
        scored.reserveCapacity(candidates.count)

        for memory in candidates {
            let haystack = Self.searchableText(for: memory)
            let lexical = SearchScoring.lexicalScore(query: text, in: haystack)
            let semantic: Double = {
                guard !queryVector.isEmpty, !memory.embedding.isEmpty else { return 0 }
                return SearchScoring.cosineSimilarity(queryVector, memory.embedding)
            }()
            let combined = SearchScoring.combined(lexical: lexical, semantic: semantic)
            if combined >= 0.05 {
                scored.append(
                    Scored(
                        memory: memory,
                        score: combined,
                        highlight: Self.highlight(text, in: haystack)
                    )
                )
            }
        }

        scored.sort { $0.score > $1.score }
        return scored.prefix(query.limit).map {
            SearchHit(memoryID: $0.memory.id, score: $0.score, highlight: $0.highlight)
        }
    }

    // MARK: - Helpers

    private static func searchableText(for memory: Memory) -> String {
        var parts: [String] = []
        switch memory.content {
        case .text(let s):                                   parts.append(s)
        case .voiceNote(let t, _):                           if let t { parts.append(t) }
        case .image(let caption):                            if let caption { parts.append(caption) }
        case .link(let url, let title, let summary):
            parts.append(url.absoluteString)
            if let title { parts.append(title) }
            if let summary { parts.append(summary) }
        case .screenshot(let ocr):                           if let ocr { parts.append(ocr) }
        case .location(let name, _, _):                      if let name { parts.append(name) }
        }
        if let summary = memory.ai.summary { parts.append(summary) }
        if let category = memory.ai.category { parts.append(category) }
        parts.append(contentsOf: memory.tags.map(\.name))
        return parts.joined(separator: " ")
    }

    /// Returns a ~120-character window centered on the first matching token,
    /// trimmed at word boundaries so snippets read naturally.
    private static func highlight(_ query: String, in haystack: String) -> String? {
        let lowercase = haystack.lowercased()
        let q = query.lowercased()
        let token = Self.longestToken(in: q) ?? q
        guard let matchRange = lowercase.range(of: token) else { return nil }

        let offset = lowercase.distance(from: lowercase.startIndex, to: matchRange.lowerBound)
        let windowStart = max(0, offset - 40)
        let windowEnd = min(haystack.count, offset + 80)
        let start = haystack.index(haystack.startIndex, offsetBy: windowStart)
        let end = haystack.index(haystack.startIndex, offsetBy: windowEnd)
        var snippet = String(haystack[start..<end])
        if windowStart > 0 { snippet = "…" + snippet }
        if windowEnd < haystack.count { snippet += "…" }
        return snippet
    }

    /// Foundation-based tokenizer. Avoids Swift's ambiguous
    /// `String.split(whereSeparator:)` overloads.
    private static func longestToken(in text: String) -> String? {
        let separators = CharacterSet.alphanumerics.inverted
        return text
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .max(by: { $0.count < $1.count })
    }
}
