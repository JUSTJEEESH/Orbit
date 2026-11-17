import Foundation

/// Remembers promises the user waved away ("not a promise"). Unlike memory
/// suggestions, these never come back: a misread sentence stays dismissed.
public protocol PromiseDismissalStore: Sendable {
    func dismissedIDs() -> Set<UUID>
    func dismiss(_ id: UUID)
}

/// Test and preview fixture.
public final class InMemoryPromiseDismissalStore: PromiseDismissalStore, @unchecked Sendable {
    private var ids: Set<UUID> = []
    private let lock = NSLock()

    public init() {}

    public func dismissedIDs() -> Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        return ids
    }

    public func dismiss(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        ids.insert(id)
    }
}
