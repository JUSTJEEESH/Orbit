import Foundation

/// Runs the AI pipeline against a saved memory. Capture writes immediately
/// with `.pending` metadata; this use case is fired in the background to
/// upgrade the memory's AI metadata to `.complete` (or `.failed`) without
/// blocking the user.
public struct EnrichMemoryUseCase: Sendable {
    private let ai: any AIService
    private let memories: any MemoryRepository
    private let clock: any OrbitClock

    public init(
        ai: any AIService,
        memories: any MemoryRepository,
        clock: any OrbitClock
    ) {
        self.ai = ai
        self.memories = memories
        self.clock = clock
    }

    /// Best-effort enrichment. Never throws — failures are recorded on the
    /// memory's status so the UI can show a retry affordance later.
    public func callAsFunction(memoryID: UUID) async {
        guard var memory = try? await memories.memory(with: memoryID) else { return }

        memory.ai.status = .processing
        try? await memories.update(memory)

        let raw = RawCapture(memory: memory)
        do {
            let result = try await ai.classify(raw)
            memory.ai = MemoryAIMetadata(
                status: .complete,
                summary: result.summary,
                category: result.category,
                priority: result.priority,
                extractedDates: result.extractedDates,
                extractedPeople: result.extractedPeople,
                extractedLocations: result.extractedLocations
            )
            let existingTagNames = Set(memory.tags.map(\.name))
            let aiTags = result.suggestedTags
                .filter { !existingTagNames.contains($0) }
                .map { Tag(name: $0, origin: .ai) }
            memory.tags.append(contentsOf: aiTags)
            memory.updatedAt = clock.now()
            try? await memories.update(memory)
        } catch {
            memory.ai.status = .failed
            memory.updatedAt = clock.now()
            try? await memories.update(memory)
        }
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
