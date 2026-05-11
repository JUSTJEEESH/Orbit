import Foundation

/// The capture-first use case. Phase 1 saves a memory immediately with
/// `.pending` AI metadata; Phase 3 enriches asynchronously after save.
public struct CaptureMemoryUseCase: Sendable {
    private let repository: any MemoryRepository
    private let clock: any OrbitClock

    public init(repository: any MemoryRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(
        content: MemoryContent,
        tags: [Tag] = [],
        media: [MediaAsset] = []
    ) async throws -> Memory {
        let now = clock.now()
        let memory = Memory(
            content: content,
            createdAt: now,
            updatedAt: now,
            tags: tags,
            media: media,
            ai: .pending
        )
        try await repository.save(memory)
        return memory
    }
}
