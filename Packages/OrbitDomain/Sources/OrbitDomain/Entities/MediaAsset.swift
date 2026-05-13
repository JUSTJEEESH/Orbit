import Foundation

/// A handle to a binary attached to a memory. The domain layer carries
/// metadata only — actual bytes live in the file system or CloudKit asset
/// store, accessed via the persistence layer.
public struct MediaAsset: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var kind: Kind
    public var filename: String
    public var byteSize: Int64
    public var createdAt: Date

    public enum Kind: String, Sendable {
        case image
        case audio
        case video
        case pdf
    }

    public init(
        id: UUID = UUID(),
        kind: Kind,
        filename: String,
        byteSize: Int64,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.byteSize = byteSize
        self.createdAt = createdAt
    }
}
