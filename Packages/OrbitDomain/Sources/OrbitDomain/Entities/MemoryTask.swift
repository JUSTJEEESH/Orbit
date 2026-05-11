import Foundation

/// A user-actionable task, optionally derived from a memory by the AI
/// extraction pipeline.
public struct MemoryTask: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var dueDate: Date?
    public var priority: MemoryAIMetadata.Priority
    public var linkedMemoryID: UUID?
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: MemoryAIMetadata.Priority = .normal,
        linkedMemoryID: UUID? = nil,
        createdAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.linkedMemoryID = linkedMemoryID
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
