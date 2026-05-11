import Foundation

/// A resurfacing or pattern-recognition insight produced by the recall engine.
public struct AIInsight: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var kind: Kind
    public var headline: String
    public var detail: String?
    public var relatedMemoryIDs: [UUID]
    public var generatedAt: Date
    public var seenAt: Date?

    public enum Kind: String, Sendable {
        case resurfacing
        case pattern
        case forgottenTask
        case milestone
    }

    public init(
        id: UUID = UUID(),
        kind: Kind,
        headline: String,
        detail: String? = nil,
        relatedMemoryIDs: [UUID] = [],
        generatedAt: Date,
        seenAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.relatedMemoryIDs = relatedMemoryIDs
        self.generatedAt = generatedAt
        self.seenAt = seenAt
    }
}
