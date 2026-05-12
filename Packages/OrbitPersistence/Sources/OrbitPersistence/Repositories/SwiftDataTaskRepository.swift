import Foundation
import SwiftData
import OrbitDomain

@ModelActor
public actor SwiftDataTaskRepository: TaskRepository {

    public func save(_ task: MemoryTask) async throws {
        let entity = MemoryTaskEntity.make(from: task)
        modelContext.insert(entity)
        try modelContext.save()
    }

    public func update(_ task: MemoryTask) async throws {
        let id = task.id
        var descriptor = FetchDescriptor<MemoryTaskEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw OrbitError.notFound
        }
        entity.apply(from: task)
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        var descriptor = FetchDescriptor<MemoryTaskEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw OrbitError.notFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }

    public func task(with id: UUID) async throws -> MemoryTask? {
        var descriptor = FetchDescriptor<MemoryTaskEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func openTasks() async throws -> [MemoryTask] {
        var descriptor = FetchDescriptor<MemoryTaskEntity>(
            predicate: #Predicate { !$0.isCompleted }
        )
        descriptor.sortBy = [
            SortDescriptor(\.dueDate, order: .forward),
            SortDescriptor(\.createdAt, order: .reverse),
        ]
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func allTasks() async throws -> [MemoryTask] {
        var descriptor = FetchDescriptor<MemoryTaskEntity>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func tasks(linkedTo memoryID: UUID) async throws -> [MemoryTask] {
        var descriptor = FetchDescriptor<MemoryTaskEntity>(
            predicate: #Predicate { $0.linkedMemoryID == memoryID }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }
}
