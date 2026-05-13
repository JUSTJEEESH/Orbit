import Foundation

public actor InMemoryTaskRepository: TaskRepository {
    private var storage: [UUID: MemoryTask] = [:]

    public init(seed: [MemoryTask] = []) {
        for task in seed { storage[task.id] = task }
    }

    public func save(_ task: MemoryTask) async throws {
        storage[task.id] = task
    }

    public func update(_ task: MemoryTask) async throws {
        guard storage[task.id] != nil else { throw OrbitError.notFound }
        storage[task.id] = task
    }

    public func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }

    public func task(with id: UUID) async throws -> MemoryTask? {
        storage[id]
    }

    public func openTasks() async throws -> [MemoryTask] {
        storage.values
            .filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    public func allTasks() async throws -> [MemoryTask] {
        storage.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func tasks(linkedTo memoryID: UUID) async throws -> [MemoryTask] {
        storage.values
            .filter { $0.linkedMemoryID == memoryID }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
