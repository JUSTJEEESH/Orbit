import Foundation

public actor InMemoryInsightRepository: InsightRepository {
    private var storage: [UUID: AIInsight] = [:]

    public init(seed: [AIInsight] = []) {
        for insight in seed { storage[insight.id] = insight }
    }

    public func recent(limit: Int) async throws -> [AIInsight] {
        storage.values
            .sorted { $0.generatedAt > $1.generatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func markSeen(id: UUID, at date: Date) async throws {
        guard var insight = storage[id] else { throw OrbitError.notFound }
        insight.seenAt = date
        storage[id] = insight
    }

    public func save(_ insight: AIInsight) async throws {
        storage[insight.id] = insight
    }
}
