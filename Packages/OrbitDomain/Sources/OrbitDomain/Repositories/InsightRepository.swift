import Foundation

public protocol InsightRepository: Sendable {
    func recent(limit: Int) async throws -> [AIInsight]
    func markSeen(id: UUID, at date: Date) async throws
    func save(_ insight: AIInsight) async throws
    /// Removes every insight. Only for the account-deletion flow.
    func deleteAll() async throws
}
