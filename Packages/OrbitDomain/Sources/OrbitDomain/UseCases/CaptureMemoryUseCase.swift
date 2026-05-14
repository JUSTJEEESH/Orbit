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
        media: [MediaAsset] = [],
        surfaceDate: Date? = nil,
        isLetter: Bool = false,
        createdAt: Date? = nil
    ) async throws -> Memory {
        let now = clock.now()
        // Optional override lets demo seeders and import flows backdate a
        // capture without bypassing the use case. Production paths leave
        // it nil and inherit clock.now() as before.
        let timestamp = createdAt ?? now
        // Discard surface dates that have already passed — a "schedule"
        // affordance with a past date should land the memory immediately
        // rather than create an instantly-visible "sealed" record.
        let effectiveSurfaceDate: Date? = {
            guard let surfaceDate, surfaceDate > now else { return nil }
            return surfaceDate
        }()
        var memory = Memory(
            content: content,
            createdAt: timestamp,
            updatedAt: timestamp,
            tags: tags,
            media: media,
            ai: .pending,
            surfaceDate: effectiveSurfaceDate,
            isLetter: isLetter
        )
        memory.ai.signals = signalExtractor.extract(from: memory)
        try await repository.save(memory)
        return memory
    }
}
