import Foundation

public struct ToggleTaskUseCase: Sendable {
    private let repository: any TaskRepository
    private let clock: any OrbitClock

    public init(repository: any TaskRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    public func callAsFunction(id: UUID) async throws -> MemoryTask? {
        guard var task = try await repository.task(with: id) else { return nil }
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? clock.now() : nil
        try await repository.update(task)
        return task
    }
}
