import Foundation

/// The canonical domain entity. A `Memory` is anything the user captured —
/// text, voice, image, link, screenshot, location. The persistence layer maps
/// this to a SwiftData `@Model`; the domain layer never knows that.
public struct Memory: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var content: MemoryContent
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [Tag]
    public var media: [MediaAsset]
    public var ai: MemoryAIMetadata
    public var linkedTaskIDs: [UUID]

    public init(
        id: UUID = UUID(),
        content: MemoryContent,
        createdAt: Date,
        updatedAt: Date,
        tags: [Tag] = [],
        media: [MediaAsset] = [],
        ai: MemoryAIMetadata = .pending,
        linkedTaskIDs: [UUID] = []
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.media = media
        self.ai = ai
        self.linkedTaskIDs = linkedTaskIDs
    }
}

public enum MemoryContent: Sendable, Hashable {
    case text(String)
    case voiceNote(transcript: String?, duration: TimeInterval)
    case image(caption: String?)
    case link(url: URL, title: String?, summary: String?)
    case screenshot(ocrText: String?)
    case location(name: String?, latitude: Double, longitude: Double)
}

public enum MemoryContentKind: String, Sendable, CaseIterable {
    case text
    case voiceNote
    case image
    case link
    case screenshot
    case location
}

public extension MemoryContent {
    var kind: MemoryContentKind {
        switch self {
        case .text:       return .text
        case .voiceNote:  return .voiceNote
        case .image:      return .image
        case .link:       return .link
        case .screenshot: return .screenshot
        case .location:   return .location
        }
    }
}

/// AI-derived metadata. Lives alongside the memory but is treated as
/// best-effort — UI must never block on its presence.
public struct MemoryAIMetadata: Sendable, Hashable {
    public var status: ProcessingStatus
    public var summary: String?
    public var category: String?
    public var priority: Priority
    public var extractedDates: [Date]
    public var extractedPeople: [String]
    public var extractedLocations: [String]

    public enum ProcessingStatus: String, Sendable {
        case pending
        case processing
        case complete
        case failed
    }

    public enum Priority: Int, Sendable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public static let pending = MemoryAIMetadata(
        status: .pending,
        summary: nil,
        category: nil,
        priority: .normal,
        extractedDates: [],
        extractedPeople: [],
        extractedLocations: []
    )

    public init(
        status: ProcessingStatus,
        summary: String?,
        category: String?,
        priority: Priority,
        extractedDates: [Date],
        extractedPeople: [String],
        extractedLocations: [String]
    ) {
        self.status = status
        self.summary = summary
        self.category = category
        self.priority = priority
        self.extractedDates = extractedDates
        self.extractedPeople = extractedPeople
        self.extractedLocations = extractedLocations
    }
}
