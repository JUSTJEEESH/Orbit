import Foundation
import OrbitDomain

/// Recovers memories that Orbit 1.x saved into the wrong store.
///
/// 1.x's Siri / Shortcuts intent opened the per-app `.onDisk` store
/// ("orbit-local" in Application Support) instead of the App Group store the
/// app reads, so "Saved to Orbit." captures never appeared anywhere. The same
/// per-app store was also the fallback whenever the App Group container was
/// unavailable. Those rows are still on the device; this copies them into
/// the main library.
///
/// Safety properties (all covered by `LegacyStoreRescueTests`):
/// - **Additive only.** Rows whose `id` already exists in the destination are
///   skipped, so running twice, or against a store that *is* the main store,
///   copies nothing.
/// - **Non-destructive.** The legacy file is never deleted or emptied; it
///   stays on disk as its own backup.
/// - **Media-aware.** Each rescued memory's media filenames are reported so
///   the caller can copy the files next to the main library's media.
public enum LegacyStoreRescue {
    public struct Outcome: Sendable, Equatable {
        public var rescuedMemoryIDs: [UUID]
        public var rescuedTaskIDs: [UUID]
        public var mediaFilenames: [String]

        public static let nothing = Outcome(rescuedMemoryIDs: [], rescuedTaskIDs: [], mediaFilenames: [])

        public var isEmpty: Bool { rescuedMemoryIDs.isEmpty && rescuedTaskIDs.isEmpty }
    }

    /// Copies every memory and task in `source` that `destination` doesn't
    /// already have. Throws only if the source can't be read at all; a single
    /// row that fails to save is skipped and the rest continue.
    public static func copyMissingRows(
        fromMemories sourceMemories: any MemoryRepository,
        tasks sourceTasks: any TaskRepository,
        intoMemories destinationMemories: any MemoryRepository,
        tasks destinationTasks: any TaskRepository
    ) async throws -> Outcome {
        var outcome = Outcome.nothing

        for memory in try await sourceMemories.list(filter: .allIncludingSealed) {
            guard try await destinationMemories.memory(with: memory.id) == nil else { continue }
            do {
                try await destinationMemories.save(memory)
                outcome.rescuedMemoryIDs.append(memory.id)
                outcome.mediaFilenames.append(contentsOf: memory.media.map(\.filename))
            } catch {
                continue
            }
        }

        for task in try await sourceTasks.allTasks() {
            guard try await destinationTasks.task(with: task.id) == nil else { continue }
            do {
                try await destinationTasks.save(task)
                outcome.rescuedTaskIDs.append(task.id)
            } catch {
                continue
            }
        }

        return outcome
    }
}
