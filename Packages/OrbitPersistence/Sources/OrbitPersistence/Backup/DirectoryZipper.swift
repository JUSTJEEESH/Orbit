import Foundation

/// Zips a directory using Foundation alone: coordinated reading with
/// `.forUploading` makes the system produce a zip of a directory, so Orbit
/// needs no third-party archive dependency.
enum DirectoryZipper {
    enum ZipError: Error, Sendable {
        case failed
    }

    /// Writes `directory` as a zip to `destination`, replacing any file
    /// already there. The source directory is left untouched.
    static func zip(_ directory: URL, to destination: URL, fileManager: FileManager = .default) throws {
        try? fileManager.removeItem(at: destination)

        var coordinationError: NSError?
        var moveError: (any Error)?
        // The system's zip only exists inside the accessor, so it's moved
        // out before the block returns.
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinationError) { zipURL in
            do {
                try fileManager.moveItem(at: zipURL, to: destination)
            } catch {
                moveError = error
            }
        }
        if coordinationError != nil || moveError != nil || !fileManager.fileExists(atPath: destination.path) {
            throw ZipError.failed
        }
    }
}
