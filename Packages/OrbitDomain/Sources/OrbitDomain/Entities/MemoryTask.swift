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
    /// The `TaskHint.id` this task was promoted from, when applicable. Lets
    /// the Tasks UI hide a hint once it has been promoted without needing to
    /// mutate the source memory's signals.
    public var sourceHintID: UUID?
    /// The `EKReminder.calendarItemIdentifier` once the task is mirrored to
    /// iOS Reminders. `nil` while Reminders sync is off or the user hasn't
    /// granted permission.
    public var remindersIdentifier: String?
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
        sourceHintID: UUID? = nil,
        remindersIdentifier: String? = nil,
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
        self.sourceHintID = sourceHintID
        self.remindersIdentifier = remindersIdentifier
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
