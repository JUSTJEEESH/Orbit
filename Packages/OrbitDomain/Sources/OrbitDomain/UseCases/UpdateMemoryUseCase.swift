import Foundation

public struct UpdateMemoryUseCase: Sendable {
    private let repository: any MemoryRepository
    private let clock: any OrbitClock

    public init(repository: any MemoryRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    public func callAsFunction(_ memory: Memory) async throws -> Memory {
        var stamped = memory
        stamped.updatedAt = clock.now()
        try await repository.update(stamped)
        return stamped
    }
}
