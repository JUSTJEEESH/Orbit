import Foundation

public struct LinkTaskToMemoryUseCase: Sendable {
    private let memories: any MemoryRepository
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(
        memories: any MemoryRepository,
        tasks: any TaskRepository,
        clock: any OrbitClock
    ) {
        self.memories = memories
        self.tasks = tasks
        self.clock = clock
    }

    public func callAsFunction(taskID: UUID, memoryID: UUID) async throws {
        guard
            var task = try await tasks.task(with: taskID),
            var memory = try await memories.memory(with: memoryID)
        else {
            throw OrbitError.notFound
        }
        task.linkedMemoryID = memoryID
        memory.linkedTaskIDs = Array(Set(memory.linkedTaskIDs + [taskID]))
        memory.updatedAt = clock.now()
        try await tasks.update(task)
        try await memories.update(memory)
    }
}
