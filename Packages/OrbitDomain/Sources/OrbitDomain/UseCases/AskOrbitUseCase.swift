import Foundation

/// Coordinates the three stages of an Ask Orbit question:
///
/// 1. **Retrieval** — hybrid search over the user's memories.
/// 2. **Grounded generation** — Foundation Models writes an answer that
///    references the retrieved memories by index.
/// 3. **Citation resolution** — citation indices become real memory IDs
///    the UI can render as source chips.
///
/// The use case stays AI-implementation-agnostic; it just orchestrates
/// the protocols. If retrieval comes back empty, it short-circuits to a
/// gentle "nothing found yet" answer rather than asking the model to
/// hallucinate.
public struct AskOrbitUseCase: Sendable {
    public enum AskOrbitError: Error, Sendable {
        case emptyQuestion
    }

    private let search: any SearchService
    private let memories: any MemoryRepository
    private let ai: any AIService
    private let clock: any OrbitClock
    private let retrievalLimit: Int

    public init(
        search: any SearchService,
        memories: any MemoryRepository,
        ai: any AIService,
        clock: any OrbitClock,
        retrievalLimit: Int = 8
    ) {
        self.search = search
        self.memories = memories
        self.ai = ai
        self.clock = clock
        self.retrievalLimit = retrievalLimit
    }

    public func callAsFunction(question: String) async throws -> AskOrbitAnswer {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AskOrbitError.emptyQuestion }

        let hits = try await search.search(SearchQuery(text: trimmed, limit: retrievalLimit))
        // Fetch full memories in hit order; drop any that have disappeared
        // between indexing and now (deleted but not yet de-indexed) AND any
        // sealed time capsules — Ask Orbit must never leak a memory the
        // user hasn't seen themselves yet.
        var retrievedMemories: [Memory] = []
        for hit in hits {
            if let memory = try? await memories.memory(with: hit.memoryID), !memory.isSealed() {
                retrievedMemories.append(memory)
            }
        }

        // Empty retrieval → don't ask the model; the user wouldn't trust an
        // answer drawn from nothing. The view treats `sourceMemoryIDs.isEmpty`
        // as a polite null state.
        guard !retrievedMemories.isEmpty else {
            return AskOrbitAnswer(
                question: trimmed,
                narrative: "I don't have any memories about that yet. As you keep capturing, ask again — I'll surface what's there.",
                sourceMemoryIDs: [],
                generatedAt: clock.now()
            )
        }

        let draft = try await ai.askOrbit(question: trimmed, memories: retrievedMemories)

        // Map citation indices to memory IDs; drop anything out of bounds
        // (defensive against malformed model output).
        let citedIDs: [UUID] = draft.citationIndices.compactMap { index in
            guard index >= 0, index < retrievedMemories.count else { return nil }
            return retrievedMemories[index].id
        }

        // If the model failed to cite anything but we did retrieve, show the
        // top hits as sources so the user can verify the answer's grounding.
        let resolvedSources = citedIDs.isEmpty
            ? Array(retrievedMemories.prefix(3).map(\.id))
            : citedIDs

        return AskOrbitAnswer(
            question: trimmed,
            narrative: draft.narrative,
            sourceMemoryIDs: resolvedSources,
            generatedAt: clock.now()
        )
    }
}
