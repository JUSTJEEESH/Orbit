import Foundation
import SwiftData

/// Version 1.0.0 of the Orbit persistence schema — the schema every 1.x build
/// shipped with. Every breaking change to any `@Model` class lives in a new
/// `OrbitSchemaVx` enum alongside a stage in `OrbitMigrationPlan`.
///
/// **Frozen. Never edit these models.** SwiftData identifies which version an
/// on-disk store is by hashing its model definitions, so this enum must keep
/// describing the 1.x store byte-for-byte: same properties, types, attributes,
/// relationships, delete rules and inverses. The live models (top-level
/// `MemoryEntity` & co.) belong to the newest schema; these nested copies
/// exist only so a 1.x store can be recognised and migrated forward, and so
/// the migration tests can build a genuine 1.x store to upgrade.
public enum OrbitSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            MemoryEntity.self,
            TagEntity.self,
            MediaAssetEntity.self,
            MemoryTaskEntity.self,
            AIInsightEntity.self,
        ]
    }

    @Model
    public final class MemoryEntity {
        @Attribute(.preserveValueOnDeletion)
        public var id: UUID = UUID()

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

        public var embedding: [Float] = []

        public var surfaceDate: Date?
        public var isLetter: Bool = false

        public var aiStatus: String = "pending"
        public var aiSummary: String?
        public var aiCategory: String?
        public var aiPriority: Int = 1
        public var aiExtractedDates: [Date] = []
        public var aiExtractedPeople: [String] = []
        public var aiExtractedLocations: [String] = []
        public var signalsJSON: Data?

        @Relationship(deleteRule: .cascade, inverse: \OrbitSchemaV1.MediaAssetEntity.memory)
        public var media: [OrbitSchemaV1.MediaAssetEntity]? = []

        @Relationship(deleteRule: .nullify, inverse: \OrbitSchemaV1.TagEntity.memories)
        public var tags: [OrbitSchemaV1.TagEntity]? = []

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
        public var memories: [OrbitSchemaV1.MemoryEntity]? = []

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

        public var memory: OrbitSchemaV1.MemoryEntity?

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
        public var sourceHintID: UUID?
        public var remindersIdentifier: String?
        public var calendarEventIdentifier: String?
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
}
