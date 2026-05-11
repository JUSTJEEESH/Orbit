import Foundation

/// Filesystem-backed storage for binary attachments (audio, images). Files
/// live under `Documents/Orbit/media/` so they're included in iCloud backup
/// and the user can wipe them by clearing the app data.
public actor MediaStorage {
    public enum Kind: String, Sendable {
        case audio
        case image

        var fileExtension: String {
            switch self {
            case .audio: return "m4a"
            case .image: return "jpg"
            }
        }
    }

    private let root: URL

    public init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let docs = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.root = docs.appendingPathComponent("Orbit/media", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, kind: Kind, id: UUID = UUID()) throws -> StoredFile {
        let filename = "\(id.uuidString).\(kind.fileExtension)"
        let url = root.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? Int64(data.count)
        return StoredFile(filename: filename, url: url, byteSize: size, kind: kind)
    }

    public func reserveURL(kind: Kind, id: UUID = UUID()) -> StoredFile {
        let filename = "\(id.uuidString).\(kind.fileExtension)"
        let url = root.appendingPathComponent(filename)
        return StoredFile(filename: filename, url: url, byteSize: 0, kind: kind)
    }

    public func finalize(_ file: StoredFile) throws -> StoredFile {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.url.path)[.size] as? Int64) ?? 0
        return StoredFile(filename: file.filename, url: file.url, byteSize: size, kind: file.kind)
    }

    public func url(forFilename filename: String) -> URL {
        root.appendingPathComponent(filename)
    }

    public func delete(filename: String) throws {
        let url = root.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}

public struct StoredFile: Sendable, Equatable {
    public let filename: String
    public let url: URL
    public let byteSize: Int64
    public let kind: MediaStorage.Kind
}
