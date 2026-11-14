import Foundation

/// How long a deleted memory stays in Recently Deleted before it is
/// permanently removed. Matches Photos and Notes, so it feels familiar.
public enum RecentlyDeletedPolicy {
    public static let retention: TimeInterval = 30 * 24 * 60 * 60
}

/// Moves a memory to Recently Deleted. This is what every "Delete" in the UI
/// does; nothing is removed from storage, so it can always be undone.
public struct MoveMemoryToTrashUseCase: Sendable {
    private let repository: any MemoryRepository
    private let clock: any OrbitClock

    public init(repository: any MemoryRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    /// - Returns: the memory as it was before deletion, for Undo.
    @discardableResult
    public func callAsFunction(id: UUID) async throws -> Memory {
        guard var memory = try await repository.memory(with: id) else { throw OrbitError.notFound }
        let original = memory
        guard memory.deletedAt == nil else { return original }
        memory.deletedAt = clock.now()
        try await repository.update(memory)
        return original
    }
}

/// Brings a memory back from Recently Deleted, exactly as it was.
public struct RestoreMemoryUseCase: Sendable {
    private let repository: any MemoryRepository

    public init(repository: any MemoryRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: UUID) async throws {
        guard var memory = try await repository.memory(with: id) else { throw OrbitError.notFound }
        guard memory.deletedAt != nil else { return }
        memory.deletedAt = nil
        try await repository.update(memory)
    }
}

/// Permanently removes memories that have been in Recently Deleted longer
/// than `RecentlyDeletedPolicy.retention`.
public struct PurgeExpiredTrashUseCase: Sendable {
    private let repository: any MemoryRepository
    private let clock: any OrbitClock

    public init(repository: any MemoryRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    /// - Returns: the purged memories, so the caller can remove their media
    ///   files and Spotlight entries.
    public func callAsFunction() async throws -> [Memory] {
        let cutoff = clock.now().addingTimeInterval(-RecentlyDeletedPolicy.retention)
        let expired = try await repository.list(filter: .recentlyDeleted)
            .filter { ($0.deletedAt ?? .distantFuture) <= cutoff }
        var purged: [Memory] = []
        for memory in expired {
            do {
                try await repository.delete(id: memory.id)
                purged.append(memory)
            } catch {
                continue
            }
        }
        return purged
    }
}
