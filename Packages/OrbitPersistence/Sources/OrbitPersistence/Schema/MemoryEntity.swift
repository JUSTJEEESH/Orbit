import Foundation
import SwiftData

/// Persistent record for a `Memory` aggregate. Flat columns instead of nested
/// associated values so the schema stays CloudKit-compatible (no unique
/// constraints, all properties defaulted, optional relationships).
@Model
public final class MemoryEntity {
    @Attribute(.preserveValueOnDeletion)
    public var id: UUID = UUID()

    /// Discriminator for the `MemoryContent` enum. Stored as `String` so the
    /// schema stays migration-friendly when new content kinds appear.
    public var contentKind: String = "text"

    public var textContent: String?
    public var voiceTranscript: String?
    public var voiceDuration: Double = 0
    public var imageCaption: String?
    public var linkURLString: String?
    public var linkTitle: String?
    public var linkSummary: String?
    public var screenshotOCRText: String?
    public var locationName: String?
    public var latitude: Double = 0
    public var longitude: Double = 0

    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var linkedTaskIDs: [UUID] = []

    /// Sentence-level semantic embedding. Empty until enrichment indexes the
    /// memory. Defaulted so the v1 schema stays migration-safe.
    public var embedding: [Float] = []

    // MARK: - AI metadata
    public var aiStatus: String = "pending"
    public var aiSummary: String?
    public var aiCategory: String?
    public var aiPriority: Int = 1
    public var aiExtractedDates: [Date] = []
    public var aiExtractedPeople: [String] = []
    public var aiExtractedLocations: [String] = []
    /// JSON-encoded `ExtractedSignals`. Stored opaquely so adding a new
    /// signal kind doesn't require a schema migration. Optional + defaulted
    /// to nil so existing CloudKit rows decode cleanly.
    public var signalsJSON: Data?

    // MARK: - Relationships (must be optional for CloudKit)
    @Relationship(deleteRule: .cascade, inverse: \MediaAssetEntity.memory)
    public var media: [MediaAssetEntity]? = []

    @Relationship(deleteRule: .nullify, inverse: \TagEntity.memories)
    public var tags: [TagEntity]? = []

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

@Model
public final class TagEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var origin: String = "user"

    @Relationship(deleteRule: .nullify)
    public var memories: [MemoryEntity]? = []

    public init(id: UUID = UUID(), name: String = "", origin: String = "user") {
        self.id = id
        self.name = name
        self.origin = origin
    }
}

@Model
public final class MediaAssetEntity {
    public var id: UUID = UUID()
    public var kind: String = "image"
    public var filename: String = ""
    public var byteSize: Int64 = 0
    public var createdAt: Date = Date()

    public var memory: MemoryEntity?

    public init(
        id: UUID = UUID(),
        kind: String = "image",
        filename: String = "",
        byteSize: Int64 = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.byteSize = byteSize
        self.createdAt = createdAt
    }
}

@Model
public final class MemoryTaskEntity {
    public var id: UUID = UUID()
    public var title: String = ""
    public var notes: String?
    public var isCompleted: Bool = false
    public var dueDate: Date?
    public var priority: Int = 1
    public var linkedMemoryID: UUID?
    /// The `TaskHint.id` this task was promoted from. Optional so existing
    /// rows decode cleanly under SwiftData's lightweight migration.
    public var sourceHintID: UUID?
    /// `EKReminder.calendarItemIdentifier` once mirrored to iOS Reminders.
    public var remindersIdentifier: String?
    public var createdAt: Date = Date()
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

@Model
public final class AIInsightEntity {
    public var id: UUID = UUID()
    public var kind: String = "resurfacing"
    public var headline: String = ""
    public var detail: String?
    public var relatedMemoryIDs: [UUID] = []
    public var generatedAt: Date = Date()
    public var seenAt: Date?

    public init(
        id: UUID = UUID(),
        kind: String = "resurfacing",
        headline: String = "",
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.generatedAt = generatedAt
    }
}
