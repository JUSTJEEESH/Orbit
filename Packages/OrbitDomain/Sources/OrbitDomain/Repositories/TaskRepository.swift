import Foundation

public protocol TaskRepository: Sendable {
    func save(_ task: MemoryTask) async throws
    func update(_ task: MemoryTask) async throws
    func delete(id: UUID) async throws
    func task(with id: UUID) async throws -> MemoryTask?
    func openTasks() async throws -> [MemoryTask]
    /// Every task in the store, completed and open. The Tasks UI uses this
    /// to render a "Recently completed" section + to compute which task
    /// hints have already been promoted.
    func allTasks() async throws -> [MemoryTask]
    func tasks(linkedTo memoryID: UUID) async throws -> [MemoryTask]
}
