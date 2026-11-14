import Foundation
import OrbitKit
import OrbitDomain

/// What the Undo toast needs to describe the deletion it can reverse.
struct TrashNotice: Identifiable, Equatable {
    let id = UUID()
    let memoryID: UUID
}

/// Deletion in Orbit 2.0 is always recoverable: the UI moves memories to
/// Recently Deleted, an Undo toast appears, and only memories left there for
/// `RecentlyDeletedPolicy.retention` (or removed by hand from Recently
/// Deleted) are erased for good.
extension AppEnvironment {
    /// Moves a memory to Recently Deleted and offers Undo. Every "Delete"
    /// in the UI calls this.
    func removeMemory(id: UUID) async throws {
        try await moveMemoryToTrash(id: id)
        await spotlight.deindex(memoryID: id)
        // Drop any pending sealed-delivery notification too — otherwise a
        // deleted time capsule would still chime on its surface date.
        // Restoring reschedules it.
        notifications.cancelSealedDelivery(memoryID: id)
        trashNotice = TrashNotice(memoryID: id)
        memoriesDidChange()
    }

    /// Brings a memory back from Recently Deleted (Undo, or the Recently
    /// Deleted screen) and re-registers everything deletion switched off.
    func restoreMemory(id: UUID) async throws {
        try await restoreMemoryFromTrash(id: id)
        if let memory = try await memories.memory(with: id) {
            await spotlight.index(memory)
        }
        scheduleSealedDeliveryIfNeeded(for: id)
        if trashNotice?.memoryID == id { trashNotice = nil }
        memoriesDidChange()
    }

    /// Erases a memory and its photo/audio files for good. Only reachable
    /// from Recently Deleted, after the user has deleted it once already.
    func deleteMemoryPermanently(id: UUID) async throws {
        let memory = try await memories.memory(with: id)
        try await deleteMemory(id: id)
        await removeMediaFiles(of: memory.map { [$0] } ?? [])
        await spotlight.deindex(memoryID: id)
        notifications.cancelSealedDelivery(memoryID: id)
        memoriesDidChange()
    }

    /// Erases everything in Recently Deleted.
    func emptyRecentlyDeleted() async throws {
        for memory in try await memories.list(filter: .recentlyDeleted) {
            try await deleteMemoryPermanently(id: memory.id)
        }
    }

    /// Launch maintenance: erases memories whose time in Recently Deleted
    /// has run out.
    func purgeExpiredRecentlyDeleted() async {
        do {
            let purged = try await purgeExpiredTrash()
            guard !purged.isEmpty else { return }
            await removeMediaFiles(of: purged)
            OrbitLog.persistence.notice("Purged \(purged.count, privacy: .public) memories past the Recently Deleted window.")
            memoriesDidChange()
        } catch {
            OrbitLog.persistence.error("Recently Deleted purge failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func removeMediaFiles(of memories: [Memory]) async {
        for asset in memories.flatMap(\.media) {
            do {
                try await mediaStorage.delete(filename: asset.filename)
            } catch {
                OrbitLog.persistence.error("Media removal failed for \(asset.filename, privacy: .public)")
            }
        }
    }
}
