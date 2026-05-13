import Foundation

public struct Tag: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var origin: Origin

    public enum Origin: String, Sendable {
        case user
        case ai
    }

    public init(id: UUID = UUID(), name: String, origin: Origin = .user) {
        self.id = id
        self.name = name
        self.origin = origin
    }
}
