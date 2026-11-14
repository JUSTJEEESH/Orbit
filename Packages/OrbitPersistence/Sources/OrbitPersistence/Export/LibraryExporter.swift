import Foundation
import OrbitDomain

/// Exports the user's library in open formats they can keep forever:
///
/// ```
/// Orbit Export 2026-11-14/
///   Orbit Memories.md   human-readable journal, newest first
///   orbit.json          every field, for re-import into Orbit or elsewhere
///   media/              original photos and recordings
/// ```
///
/// Zipped into one file for the share sheet. Memories in Recently Deleted
/// are left out; sealed letters are included (they're the user's own words)
/// and marked with the date they unseal.
public enum LibraryExporter {
    public enum ExportError: Error, Sendable {
        case emptyLibrary
        case zipFailed
    }

    /// Bumped if the JSON shape ever changes incompatibly.
    static let formatVersion = 1

    /// - Parameter mediaURL: resolves a stored media filename to its file.
    ///   Injected so this layer doesn't depend on `MediaStorage`.
    public static func export(
        memories memoryRepository: any MemoryRepository,
        tasks taskRepository: any TaskRepository,
        mediaURL: @Sendable (String) async -> URL,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) async throws -> URL {
        let stamp = ISO8601DateFormatter.archiveStamp.string(from: now)
        let name = "Orbit Export \(stamp)"
        let staging = fileManager.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try? fileManager.removeItem(at: staging)
        defer { try? fileManager.removeItem(at: staging) }

        try await writeExport(
            to: staging,
            memories: memoryRepository,
            tasks: taskRepository,
            mediaURL: mediaURL,
            fileManager: fileManager,
            now: now
        )

        let destination = fileManager.temporaryDirectory.appendingPathComponent("\(name).zip")
        do {
            try DirectoryZipper.zip(staging, to: destination, fileManager: fileManager)
        } catch {
            throw ExportError.zipFailed
        }
        return destination
    }

    /// Writes the unzipped export folder. Split from `export` so tests can
    /// inspect exactly what the user receives.
    static func writeExport(
        to folder: URL,
        memories memoryRepository: any MemoryRepository,
        tasks taskRepository: any TaskRepository,
        mediaURL: @Sendable (String) async -> URL,
        fileManager: FileManager,
        now: Date
    ) async throws {
        let memories = try await memoryRepository.list(filter: MemoryFilter(sort: .newestFirst, includeSealed: true))
        let tasks = try await taskRepository.allTasks()
        guard !memories.isEmpty || !tasks.isEmpty else { throw ExportError.emptyLibrary }

        let mediaFolder = folder.appendingPathComponent("media", isDirectory: true)
        try fileManager.createDirectory(at: mediaFolder, withIntermediateDirectories: true)

        // Media first, so the JSON and Markdown only reference files that
        // actually made it into the export.
        var exportedFiles: Set<String> = []
        for asset in memories.flatMap(\.media) where !exportedFiles.contains(asset.filename) {
            let source = await mediaURL(asset.filename)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(at: source, to: mediaFolder.appendingPathComponent(asset.filename))
            exportedFiles.insert(asset.filename)
        }

        let document = ExportDocument(
            format: formatVersion,
            exportedAt: now,
            memories: memories.map { ExportedMemory($0, exportedFiles: exportedFiles) },
            tasks: tasks.map(ExportedTask.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(document).write(to: folder.appendingPathComponent("orbit.json"), options: .atomic)

        let markdown = MarkdownJournal.render(memories: memories, tasks: tasks, exportedFiles: exportedFiles, exportedAt: now)
        try Data(markdown.utf8).write(to: folder.appendingPathComponent("Orbit Memories.md"), options: .atomic)
    }
}

// MARK: - JSON shape

struct ExportDocument: Codable {
    var format: Int
    var exportedAt: Date
    var memories: [ExportedMemory]
    var tasks: [ExportedTask]
}

struct ExportedMemory: Codable, Equatable {
    struct Place: Codable, Equatable {
        var name: String?
        var latitude: Double
        var longitude: Double
    }

    struct Media: Codable, Equatable {
        var kind: String
        /// Path inside the export, e.g. `media/<uuid>.jpg`.
        var file: String
    }

    var id: UUID
    var kind: String
    var createdAt: Date
    var updatedAt: Date
    var text: String?
    var transcript: String?
    var durationSeconds: Double?
    var caption: String?
    var url: String?
    var title: String?
    var summary: String?
    var screenshotText: String?
    var place: Place?
    var tags: [String]
    var media: [Media]
    var isLetter: Bool
    var sealedUntil: Date?
    var aiSummary: String?
    var aiCategory: String?
    var people: [String]
    var places: [String]
    var mentionedDates: [Date]

    init(_ memory: Memory, exportedFiles: Set<String>) {
        id = memory.id
        kind = memory.content.kind.rawValue
        createdAt = memory.createdAt
        updatedAt = memory.updatedAt
        switch memory.content {
        case .text(let s):
            text = s
        case .voiceNote(let t, let duration):
            transcript = t
            durationSeconds = duration
        case .image(let c):
            caption = c
        case .link(let u, let t, let s):
            url = u.absoluteString
            title = t
            summary = s
        case .screenshot(let ocr):
            screenshotText = ocr
        case .location(let name, let latitude, let longitude):
            place = Place(name: name, latitude: latitude, longitude: longitude)
        }
        tags = memory.tags.map(\.name)
        media = memory.media
            .filter { exportedFiles.contains($0.filename) }
            .map { Media(kind: $0.kind.rawValue, file: "media/\($0.filename)") }
        isLetter = memory.isLetter
        sealedUntil = memory.surfaceDate
        aiSummary = memory.ai.summary
        aiCategory = memory.ai.category
        people = memory.ai.extractedPeople
        places = memory.ai.extractedLocations
        mentionedDates = memory.ai.extractedDates
    }
}

struct ExportedTask: Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String?
    var isCompleted: Bool
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?
    var linkedMemoryID: UUID?

    init(_ task: MemoryTask) {
        id = task.id
        title = task.title
        notes = task.notes
        isCompleted = task.isCompleted
        dueDate = task.dueDate
        createdAt = task.createdAt
        completedAt = task.completedAt
        linkedMemoryID = task.linkedMemoryID
    }
}

// MARK: - Markdown

enum MarkdownJournal {
    static func render(memories: [Memory], tasks: [MemoryTask], exportedFiles: Set<String>, exportedAt: Date) -> String {
        let dayFormat = Date.FormatStyle(date: .complete, time: .omitted)
        let timeFormat = Date.FormatStyle(date: .omitted, time: .shortened)
        var lines: [String] = [
            "# Orbit",
            "",
            "Exported \(exportedAt.formatted(date: .long, time: .shortened)) · \(memories.count) memories · \(tasks.count) tasks",
            "",
        ]

        var currentDay: String?
        for memory in memories {
            let day = memory.createdAt.formatted(dayFormat)
            if day != currentDay {
                lines += ["## \(day)", ""]
                currentDay = day
            }
            var heading = "### \(memory.createdAt.formatted(timeFormat))"
            if memory.isLetter { heading += " · Letter" }
            if let sealed = memory.surfaceDate {
                heading += " · Sealed until \(sealed.formatted(date: .long, time: .omitted))"
            }
            lines += [heading, ""]
            lines += body(of: memory)
            for asset in memory.media where exportedFiles.contains(asset.filename) {
                let path = "media/\(asset.filename)"
                lines.append(asset.kind == .image ? "![Photo](\(path))" : "[Recording](\(path))")
            }
            if !memory.tags.isEmpty {
                lines.append("Tags: " + memory.tags.map { "#\($0.name)" }.joined(separator: " "))
            }
            lines.append("")
        }

        if !tasks.isEmpty {
            lines += ["## Tasks", ""]
            for task in tasks {
                var line = "- [\(task.isCompleted ? "x" : " ")] \(task.title)"
                if let due = task.dueDate { line += " (due \(due.formatted(date: .abbreviated, time: .omitted)))" }
                lines.append(line)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func body(of memory: Memory) -> [String] {
        switch memory.content {
        case .text(let s):
            return [s, ""]
        case .voiceNote(let transcript, let duration):
            let length = Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))
            return ["Voice note (\(length))" + (transcript.map { ": \($0)" } ?? ""), ""]
        case .image(let caption):
            return caption.map { [$0, ""] } ?? []
        case .link(let url, let title, let summary):
            var lines = ["[\(title ?? url.absoluteString)](\(url.absoluteString))"]
            if let summary { lines.append(summary) }
            return lines + [""]
        case .screenshot(let ocr):
            return ocr.map { [$0, ""] } ?? []
        case .location(let name, let latitude, let longitude):
            return ["Place: \(name ?? "Unnamed") (\(latitude), \(longitude))", ""]
        }
    }
}
