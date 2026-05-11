import Foundation

public protocol TaskRepository: Sendable {
    func save(_ task: MemoryTask) async throws
    func update(_ task: MemoryTask) async throws
    func delete(id: UUID) async throws
    func task(with id: UUID) async throws -> MemoryTask?
    func openTasks() async throws -> [MemoryTask]
    func tasks(linkedTo memoryID: UUID) async throws -> [MemoryTask]
}
