import Foundation

/// Runs the AI pipeline against a saved memory. Capture writes immediately
/// with `.pending` metadata; this use case is fired in the background to
/// upgrade the memory's AI metadata to `.complete` (or `.failed`) without
/// blocking the user.
public struct EnrichMemoryUseCase: Sendable {
    private let ai: any AIService
    private let memories: any MemoryRepository
    private let clock: any OrbitClock
    private let signalExtractor: any SignalExtracting

    public init(
        ai: any AIService,
        memories: any MemoryRepository,
        clock: any OrbitClock,
        signalExtractor: any SignalExtracting = NoOpSignalExtractor()
    ) {
        self.ai = ai
        self.memories = memories
        self.clock = clock
        self.signalExtractor = signalExtractor
    }

    /// Best-effort enrichment. Never throws — failures are recorded on the
    /// memory's status so the UI can show a retry affordance later.
    ///
    /// The model can take seconds, and the user can edit (or delete) the
    /// memory meanwhile. So the result is merged into a *fresh* read of the
    /// memory, touching only AI-owned fields — never written back over the
    /// copy that was read before the model ran. If the content itself
    /// changed mid-flight, the result describes stale text: the memory goes
    /// back to `.pending` for the next pass instead.
    public func callAsFunction(memoryID: UUID) async {
        guard var memory = try? await memories.memory(with: memoryID) else { return }

        memory.ai.status = .processing
        try? await memories.update(memory)

        let enrichedContent = memory.content
        let raw = RawCapture(memory: memory)
        // Re-run signal extraction during enrichment so older memories
        // captured before the SignalExtractor existed pick up signals via
        // the re-enrich-all flow without needing a separate migration.
        let refreshedSignals = signalExtractor.extract(from: memory)
        do {
            let result = try await ai.classify(raw)
            let metadata = MemoryAIMetadata(
                status: .complete,
                summary: result.summary,
                category: result.category,
                priority: result.priority,
                extractedDates: result.extractedDates,
                extractedPeople: result.extractedPeople,
                extractedLocations: result.extractedLocations,
                signals: refreshedSignals
            )

            // Index for semantic search. Embedding failure isn't fatal —
            // the memory still saves with lexical-only ranking available.
            var embedding: [Float]?
            if let indexable = Self.indexableText(memory: memory, classification: result) {
                embedding = (try? await ai.embed(indexable)) ?? []
            }

            // Deleted while the model ran: nothing to write.
            guard var latest = try? await memories.memory(with: memoryID) else { return }
            guard latest.content == enrichedContent else {
                latest.ai.status = .pending
                try? await memories.update(latest)
                return
            }
            latest.ai = metadata
            let existingTagNames = Set(latest.tags.map(\.name))
            let aiTags = result.suggestedTags
                .filter { !existingTagNames.contains($0) }
                .map { Tag(name: $0, origin: .ai) }
            latest.tags.append(contentsOf: aiTags)
            if let embedding { latest.embedding = embedding }
            latest.updatedAt = clock.now()
            try? await memories.update(latest)
        } catch {
            guard var latest = try? await memories.memory(with: memoryID) else { return }
            latest.ai.status = .failed
            latest.updatedAt = clock.now()
            try? await memories.update(latest)
        }
    }

    /// The text we hand to the embedding model. Combines raw content with
    /// the AI's summary and tags so semantically-similar captures cluster
    /// even when their surface vocabulary differs.
    private static func indexableText(
        memory: Memory,
        classification: ClassificationResult
    ) -> String? {
        var parts: [String] = []
        switch memory.content {
        case .text(let s):                  parts.append(s)
        case .voiceNote(let t, _):          if let t { parts.append(t) }
        case .image(let caption):           if let caption { parts.append(caption) }
        case .link(let url, let title, let summary):
            parts.append(url.absoluteString)
            if let title { parts.append(title) }
            if let summary { parts.append(summary) }
        case .screenshot(let ocr):          if let ocr { parts.append(ocr) }
        case .location(let name, _, _):     if let name { parts.append(name) }
        }
        if let summary = classification.summary { parts.append(summary) }
        if let category = classification.category { parts.append(category) }
        parts.append(contentsOf: classification.suggestedTags)
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}

extension RawCapture {
    /// Convenience initializer that flattens a `Memory`'s content shape into
    /// the `RawCapture` payload expected by `AIService`.
    public init(memory: Memory) {
        switch memory.content {
        case .text(let s):
            self.init(text: s)
        case .voiceNote(let transcript, _):
            self.init(audioTranscript: transcript)
        case .image(let caption):
            self.init(text: caption)
        case .link(let url, let title, let summary):
            let context = [title, summary].compactMap { $0 }.joined(separator: " — ")
            self.init(text: context.isEmpty ? nil : context, url: url)
        case .screenshot(let ocr):
            self.init(text: ocr)
        case .location(let name, _, _):
            self.init(text: name)
        }
    }
}
