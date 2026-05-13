import Foundation

/// Typed navigation route for pushing a memory's detail view. We navigate by
/// ID rather than by `Memory` value so the navigation path stays cheap to
/// hash and the destination always reads the freshest state from the
/// repository.
public struct MemoryDetailRoute: Hashable, Sendable {
    public let memoryID: UUID

    public init(memoryID: UUID) {
        self.memoryID = memoryID
    }
}
