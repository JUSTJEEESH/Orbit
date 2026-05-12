import Foundation

/// Returns every task in the store sorted newest-first by creation, so the
/// Tasks UI can split them into Today / Soon / All / Completed in memory.
public struct ListTasksUseCase: Sendable {
    private let repository: any TaskRepository

    public init(repository: any TaskRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> [MemoryTask] {
        try await repository.allTasks()
    }
}
