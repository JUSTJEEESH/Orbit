import Foundation

public struct DeleteTaskUseCase: Sendable {
    private let tasks: any TaskRepository

    public init(tasks: any TaskRepository) {
        self.tasks = tasks
    }

    public func callAsFunction(id: UUID) async throws {
        try await tasks.delete(id: id)
    }
}
