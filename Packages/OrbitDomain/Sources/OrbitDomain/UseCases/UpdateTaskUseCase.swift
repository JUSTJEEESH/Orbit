import Foundation

/// Persists in-place edits to a task — title, due date, notes, priority,
/// completion state. Callers should set `completedAt` themselves when
/// flipping `isCompleted`; this use case is intentionally just a pass-
/// through so future side effects (Reminders sync, widget refresh) can
/// hang off a single chokepoint.
public struct UpdateTaskUseCase: Sendable {
    private let tasks: any TaskRepository

    public init(tasks: any TaskRepository) {
        self.tasks = tasks
    }

    public func callAsFunction(_ task: MemoryTask) async throws {
        try await tasks.update(task)
    }
}
