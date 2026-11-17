import Foundation
import SwiftData

/// Test fixture: the schema an unreleased 2.0 build wrote — 1.x plus
/// `deletedAt` only, before transcript timings and promises were added.
/// Stores like this exist on TestFlight and developer devices; it matches
/// no version in `OrbitMigrationPlan`, which is exactly what the
/// inferred-migration fallback must handle without losing a row.
enum OrbitSchemaInterim: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 9, 0)

    static var models: [any PersistentModel.Type] {
        [
            MemoryEntity.self,
            TagEntity.self,
            MediaAssetEntity.self,
            MemoryTaskEntity.self,
            AIInsightEntity.self,
        ]
    }

    @Model
    final class MemoryEntity {
        @Attribute(.preserveValueOnDeletion)
        var id: UUID = UUID()

        var contentKind: String = "text"

        var textContent: String?
        var voiceTranscript: String?
        var voiceDuration: Double = 0
        var imageCaption: String?
        var linkURLString: String?
        var linkTitle: String?
        var linkSummary: String?
        var screenshotOCRText: String?
        var locationName: String?
        var latitude: Double = 0
        var longitude: Double = 0

        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var linkedTaskIDs: [UUID] = []

        var embedding: [Float] = []

        var surfaceDate: Date?
        var isLetter: Bool = false
        var deletedAt: Date?

        var aiStatus: String = "pending"
        var aiSummary: String?
        var aiCategory: String?
        var aiPriority: Int = 1
        var aiExtractedDates: [Date] = []
        var aiExtractedPeople: [String] = []
        var aiExtractedLocations: [String] = []
        var signalsJSON: Data?

        @Relationship(deleteRule: .cascade, inverse: \OrbitSchemaInterim.MediaAssetEntity.memory)
        var media: [OrbitSchemaInterim.MediaAssetEntity]? = []

        @Relationship(deleteRule: .nullify, inverse: \OrbitSchemaInterim.TagEntity.memories)
        var tags: [OrbitSchemaInterim.TagEntity]? = []

        init(id: UUID = UUID()) {
            self.id = id
        }
    }

    @Model
    final class TagEntity {
        var id: UUID = UUID()
        var name: String = ""
        var origin: String = "user"

        @Relationship(deleteRule: .nullify)
        var memories: [OrbitSchemaInterim.MemoryEntity]? = []

        init(id: UUID = UUID(), name: String = "", origin: String = "user") {
            self.id = id
            self.name = name
            self.origin = origin
        }
    }

    @Model
    final class MediaAssetEntity {
        var id: UUID = UUID()
        var kind: String = "image"
        var filename: String = ""
        var byteSize: Int64 = 0
        var createdAt: Date = Date()

        var memory: OrbitSchemaInterim.MemoryEntity?

        init(
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
    final class MemoryTaskEntity {
        var id: UUID = UUID()
        var title: String = ""
        var notes: String?
        var isCompleted: Bool = false
        var dueDate: Date?
        var priority: Int = 1
        var linkedMemoryID: UUID?
        var sourceHintID: UUID?
        var remindersIdentifier: String?
        var calendarEventIdentifier: String?
        var createdAt: Date = Date()
        var completedAt: Date?

        init(
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
    final class AIInsightEntity {
        var id: UUID = UUID()
        var kind: String = "resurfacing"
        var headline: String = ""
        var detail: String?
        var relatedMemoryIDs: [UUID] = []
        var generatedAt: Date = Date()
        var seenAt: Date?

        init(
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

