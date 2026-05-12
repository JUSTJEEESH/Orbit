import Foundation

/// Creates a `MemoryTask` from a `TaskHint` extracted on a memory. The
/// returned task carries `sourceHintID` so the suggestion surface knows to
/// hide that hint thereafter, and `linkedMemoryID` so the task row can deep
/// link back to its source memory.
public struct PromoteHintToTaskUseCase: Sendable {
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(tasks: any TaskRepository, clock: any OrbitClock) {
        self.tasks = tasks
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(memory: Memory, hint: TaskHint) async throws -> MemoryTask {
        let task = MemoryTask(
            title: hint.phrase,
            dueDate: hint.dueDate,
            linkedMemoryID: memory.id,
            sourceHintID: hint.id,
            createdAt: clock.now()
        )
        try await tasks.save(task)
        return task
    }
}
