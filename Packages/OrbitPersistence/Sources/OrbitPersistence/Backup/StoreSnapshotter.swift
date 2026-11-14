import Foundation
import os

/// Copies the SwiftData store files aside before a schema upgrade touches
/// them, so the exact pre-update database always exists on the device.
///
/// Why this lives in the persistence layer: after an App Store update, the
/// first process to open the store may be the Share Extension, a widget or
/// an App Intent rather than the app. `ModelContainerFactory` calls this
/// before *every* App Group container open, so whichever process opens the
/// store first takes the snapshot before SwiftData migrates anything.
///
/// Snapshots are keyed by the schema version being opened, so each version
/// is snapshotted once and ordinary launches cost one `fileExists` check.
/// Snapshots are never deleted automatically except to keep the newest
/// `retainedSnapshots`; the newest is always kept.
public enum StoreSnapshotter {
    /// How many per-version snapshots to keep. Each is a full copy of the
    /// store (a few MB for most users), and a new one only appears when the
    /// schema version changes, so three covers several releases.
    public static let retainedSnapshots = 3

    private static let manifestName = "snapshot.json"
    private static let logger = Logger(subsystem: "com.joshgreen.orbit", category: "persistence.snapshot")

    public struct Manifest: Codable, Sendable, Equatable {
        public var label: String
        public var createdAt: Date
        public var files: [String: Int64]
    }

    /// Snapshots `storeURL` (plus its `-wal` / `-shm` companions) into
    /// `backupsDirectory/<label>/` unless that snapshot already exists.
    ///
    /// Never throws and never touches the original files: a failed snapshot
    /// is logged and the caller carries on opening the store as before.
    ///
    /// - Returns: the snapshot directory if one exists for `label` after the
    ///   call (created now or earlier), or `nil` when there is no store yet
    ///   (fresh install) or the copy failed.
    @discardableResult
    public static func snapshotIfNeeded(
        storeURL: URL,
        label: String,
        backupsDirectory: URL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) -> URL? {
        let destination = backupsDirectory.appendingPathComponent(label, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) { return destination }
        // Fresh install: nothing to protect yet.
        guard fileManager.fileExists(atPath: storeURL.path) else { return nil }

        // Copy into a uniquely named staging folder, then rename it into
        // place. The rename is atomic, so a reader never sees a half-written
        // snapshot, and if two processes race only one rename wins.
        let staging = backupsDirectory.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            var files: [String: Int64] = [:]
            for source in storeFiles(for: storeURL) where fileManager.fileExists(atPath: source.path) {
                let target = staging.appendingPathComponent(source.lastPathComponent)
                try fileManager.copyItem(at: source, to: target)
                let size = (try? fileManager.attributesOfItem(atPath: target.path)[.size] as? Int64) ?? 0
                files[source.lastPathComponent] = size
            }
            let manifest = Manifest(label: label, createdAt: now, files: files)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: staging.appendingPathComponent(manifestName), options: .atomic)
            try fileManager.moveItem(at: staging, to: destination)
            logger.notice("Store snapshot created: \(label, privacy: .public)")
        } catch {
            try? fileManager.removeItem(at: staging)
            // Another process may have won the race; that's a success.
            if fileManager.fileExists(atPath: destination.path) { return destination }
            logger.error("Store snapshot failed for \(label, privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }

        pruneOldSnapshots(in: backupsDirectory, keeping: destination, fileManager: fileManager)
        return destination
    }

    /// All snapshots in `backupsDirectory`, newest first.
    public static func snapshots(in backupsDirectory: URL, fileManager: FileManager = .default) -> [(url: URL, manifest: Manifest)] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries.compactMap { url in
            guard let data = try? Data(contentsOf: url.appendingPathComponent(manifestName)),
                  let manifest = try? decoder.decode(Manifest.self, from: data)
            else { return nil }
            return (url, manifest)
        }
        .sorted { $0.manifest.createdAt > $1.manifest.createdAt }
    }

    /// SQLite keeps recent writes in the `-wal` file until a checkpoint, so
    /// copying `orbit.sqlite` alone could miss the user's latest memories.
    static func storeFiles(for storeURL: URL) -> [URL] {
        let path = storeURL.path
        return [storeURL, URL(fileURLWithPath: path + "-wal"), URL(fileURLWithPath: path + "-shm")]
    }

    private static func pruneOldSnapshots(in backupsDirectory: URL, keeping newest: URL, fileManager: FileManager) {
        let all = snapshots(in: backupsDirectory, fileManager: fileManager)
        guard all.count > retainedSnapshots else { return }
        for old in all.dropFirst(retainedSnapshots) where old.url.standardizedFileURL != newest.standardizedFileURL {
            try? fileManager.removeItem(at: old.url)
        }
    }
}
