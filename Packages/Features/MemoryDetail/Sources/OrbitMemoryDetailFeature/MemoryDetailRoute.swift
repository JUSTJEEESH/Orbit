import Foundation

/// Typed navigation route for pushing a memory's detail view. We navigate by
/// ID rather than by `Memory` value so the navigation path stays cheap to
/// hash and the destination always reads the freshest state from the
/// repository.
public struct MemoryDetailRoute: Hashable, Sendable {
    public let memoryID: UUID
    /// What the user searched for, when they arrived from Search. Voice
    /// notes use it to offer playback from the moment the words were said.
    public let searchQuery: String?

    public init(memoryID: UUID, searchQuery: String? = nil) {
        self.memoryID = memoryID
        self.searchQuery = searchQuery
    }
}
