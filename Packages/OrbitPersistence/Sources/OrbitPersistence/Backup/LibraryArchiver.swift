import Foundation

/// Packs the raw on-device library — SwiftData store files, pre-upgrade
/// snapshots and media — into a single `.zip` the user can save to Files or
/// send to support.
///
/// This is the last-resort escape hatch behind the Recovery screen: it works
/// even when SwiftData can't open the store, because it only copies files.
/// The originals are never moved or modified.
public enum LibraryArchiver {
    public enum ArchiveError: Error, Sendable {
        case appGroupUnavailable
        case nothingToArchive
        case zipFailed
    }

    /// Folders (relative to the App Group container) that hold user data.
    static let archivedFolders = ["Library/SwiftData", "Library/Backups", "Orbit/media"]

    /// Builds the archive in the temporary directory and returns its URL.
    /// Runs synchronously; call it off the main actor for large libraries.
    public static func makeArchive(
        appGroupIdentifier: String,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> URL {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw ArchiveError.appGroupUnavailable
        }
        return try makeArchive(from: container, folders: archivedFolders, fileManager: fileManager, now: now)
    }

    static func makeArchive(
        from root: URL,
        folders: [String],
        fileManager: FileManager,
        now: Date
    ) throws -> URL {
        let stamp = ISO8601DateFormatter.archiveStamp.string(from: now)
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent("Orbit-Library-\(stamp)", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        var copiedAnything = false
        for folder in folders {
            let source = root.appendingPathComponent(folder, isDirectory: true)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = staging.appendingPathComponent(folder, isDirectory: true)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source, to: target)
            copiedAnything = true
        }
        guard copiedAnything else { throw ArchiveError.nothingToArchive }

        let destination = fileManager.temporaryDirectory.appendingPathComponent("Orbit-Library-\(stamp).zip")
        do {
            try DirectoryZipper.zip(staging, to: destination, fileManager: fileManager)
        } catch {
            throw ArchiveError.zipFailed
        }
        return destination
    }
}

extension ISO8601DateFormatter {
    /// `2026-11-14` style stamp: readable in Files, safe in filenames.
    static var archiveStamp: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }
}
