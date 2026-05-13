import Foundation
import SwiftData
import OrbitDomain

@ModelActor
public actor SwiftDataInsightRepository: InsightRepository {

    public func recent(limit: Int) async throws -> [AIInsight] {
        var descriptor = FetchDescriptor<AIInsightEntity>()
        descriptor.sortBy = [SortDescriptor(\.generatedAt, order: .reverse)]
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func markSeen(id: UUID, at date: Date) async throws {
        var descriptor = FetchDescriptor<AIInsightEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw OrbitError.notFound
        }
        entity.seenAt = date
        try modelContext.save()
    }

    public func save(_ insight: AIInsight) async throws {
        let entity = AIInsightEntity.make(from: insight)
        modelContext.insert(entity)
        try modelContext.save()
    }
}
