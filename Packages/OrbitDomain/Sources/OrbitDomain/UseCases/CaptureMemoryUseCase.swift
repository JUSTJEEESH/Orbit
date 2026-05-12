import Foundation

/// The capture-first use case. Saves a memory immediately with `.pending`
/// AI metadata, but populates `signals` synchronously so feature surfaces
/// (Tasks, Reading list, Habits) light up the moment the memory is saved —
/// no waiting for the AI pipeline to finish.
public struct CaptureMemoryUseCase: Sendable {
    private let repository: any MemoryRepository
    private let clock: any OrbitClock
    private let signalExtractor: any SignalExtracting

    public init(
        repository: any MemoryRepository,
        clock: any OrbitClock,
        signalExtractor: any SignalExtracting = NoOpSignalExtractor()
    ) {
        self.repository = repository
        self.clock = clock
        self.signalExtractor = signalExtractor
    }

    @discardableResult
    public func callAsFunction(
        content: MemoryContent,
        tags: [Tag] = [],
        media: [MediaAsset] = []
    ) async throws -> Memory {
        let now = clock.now()
        var memory = Memory(
            content: content,
            createdAt: now,
            updatedAt: now,
            tags: tags,
            media: media,
            ai: .pending
        )
        memory.ai.signals = signalExtractor.extract(from: memory)
        try await repository.save(memory)
        return memory
    }
}
