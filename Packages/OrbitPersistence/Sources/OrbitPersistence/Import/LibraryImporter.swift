import Foundation
import OrbitDomain

/// Brings memories in from other apps and from Orbit's own export.
///
/// Supported files:
/// - **Day One** `Journal.json` (from a Day One JSON export, once unzipped
///   in Files): text, date, tags and place for each entry.
/// - **Orbit** `orbit.json` (from Export Everything): every memory and task,
///   restored with their original IDs.
/// - **Text / Markdown** files: one memory per file, dated by the file.
///
/// Importing is additive and idempotent: entries keep a stable ID derived
/// from their source, and anything already in the library is skipped, so
/// importing the same file twice never duplicates. Photos inside exports
/// aren't imported yet; their text, dates and tags are.
public enum LibraryImporter {
    public struct Summary: Sendable, Equatable {
        public var importedMemories = 0
        public var importedTasks = 0
        public var skippedDuplicates = 0
        public var unreadableFiles = 0
        public var importedMemoryIDs: [UUID] = []

        public init() {}
    }

    struct Parsed {
        var memories: [Memory] = []
        var tasks: [MemoryTask] = []
    }

    /// Imports every readable file and saves new memories and tasks.
    public static func importFiles(
        _ urls: [URL],
        memories memoryRepository: any MemoryRepository,
        tasks taskRepository: any TaskRepository,
        now: Date = Date()
    ) async throws -> Summary {
        var summary = Summary()
        for url in urls {
            // Files chosen in the document picker are security-scoped.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let parsed = try? parse(fileAt: url, now: now) else {
                summary.unreadableFiles += 1
                continue
            }
            for memory in parsed.memories {
                if try await memoryRepository.memory(with: memory.id) != nil {
                    summary.skippedDuplicates += 1
                    continue
                }
                try await memoryRepository.save(memory)
                summary.importedMemories += 1
                summary.importedMemoryIDs.append(memory.id)
            }
            for task in parsed.tasks {
                if try await taskRepository.task(with: task.id) != nil { continue }
                try await taskRepository.save(task)
                summary.importedTasks += 1
            }
        }
        return summary
    }

    static func parse(fileAt url: URL, now: Date) throws -> Parsed {
        let data = try Data(contentsOf: url)
        switch url.pathExtension.lowercased() {
        case "json":
            return try parseJSON(data)
        default:
            let text = String(decoding: data, as: UTF8.self)
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = values?.creationDate ?? values?.contentModificationDate ?? now
            return parseText(text, name: url.deletingPathExtension().lastPathComponent, createdAt: created)
        }
    }

    // MARK: - JSON

    static func parseJSON(_ data: Data) throws -> Parsed {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let orbit = try? decoder.decode(ExportDocument.self, from: data) {
            return Parsed(memories: orbit.memories.map { $0.restoredMemory() }, tasks: orbit.tasks.map { $0.restoredTask() })
        }
        let dayOne = try decoder.decode(DayOneJournal.self, from: data)
        return Parsed(memories: dayOne.entries.compactMap { $0.memory() })
    }

    // MARK: - Text

    static func parseText(_ text: String, name: String, createdAt: Date) -> Parsed {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Parsed() }
        let memory = Memory(
            id: stableID(for: "text:\(name):\(createdAt.timeIntervalSince1970):\(trimmed.count)"),
            content: .text(trimmed),
            createdAt: createdAt,
            updatedAt: createdAt
        )
        return Parsed(memories: [memory])
    }

    /// A UUID derived from a string, so re-importing the same source yields
    /// the same ID (and is skipped as a duplicate). FNV-1a, spread over 128
    /// bits — collision-resistant enough for de-duplication.
    static func stableID(for source: String) -> UUID {
        var high: UInt64 = 0xcbf29ce484222325
        var low: UInt64 = 0x84222325cbf29ce4
        for byte in source.utf8 {
            high = (high ^ UInt64(byte)) &* 0x100000001b3
            low = (low ^ UInt64(byte)) &* 0x100000001b3 &+ high
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8(truncatingIfNeeded: high >> (index * 8))
            bytes[index + 8] = UInt8(truncatingIfNeeded: low >> (index * 8))
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

// MARK: - Day One

/// The subset of Day One's JSON export Orbit reads.
struct DayOneJournal: Decodable {
    struct Entry: Decodable {
        struct Location: Decodable {
            var placeName: String?
            var localityName: String?
            var latitude: Double?
            var longitude: Double?
        }

        var uuid: String?
        var creationDate: Date
        var modifiedDate: Date?
        var text: String?
        var tags: [String]?
        var location: Location?

        func memory() -> Memory? {
            let body = (text ?? "")
                // Day One escapes Markdown punctuation and embeds photo
                // placeholders; neither belongs in a plain memory.
                .replacingOccurrences(of: #"!\[\]\(dayone-moment:[^)]*\)"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            let id = uuid.flatMap(Self.uuid(fromDayOne:)) ?? LibraryImporter.stableID(for: "dayone:\(creationDate.timeIntervalSince1970):\(body)")
            var memory = Memory(
                id: id,
                content: .text(body),
                createdAt: creationDate,
                updatedAt: modifiedDate ?? creationDate,
                tags: (tags ?? []).map { Tag(name: $0, origin: .user) }
            )
            if let place = location?.placeName ?? location?.localityName {
                memory.ai.extractedLocations = [place]
            }
            return memory
        }

        /// Day One IDs are 32 hex digits without dashes.
        static func uuid(fromDayOne raw: String) -> UUID? {
            let hex = raw.replacingOccurrences(of: "-", with: "")
            guard hex.count == 32 else { return UUID(uuidString: raw) }
            var dashed = hex
            for offset in [20, 16, 12, 8] {
                dashed.insert("-", at: dashed.index(dashed.startIndex, offsetBy: offset))
            }
            return UUID(uuidString: dashed)
        }
    }

    var entries: [Entry]
}

// MARK: - Orbit export → domain

extension ExportedMemory {
    func restoredMemory() -> Memory {
        let content: MemoryContent
        switch MemoryContentKind(rawValue: kind) ?? .text {
        case .text:       content = .text(text ?? "")
        case .voiceNote:  content = .voiceNote(transcript: transcript, duration: durationSeconds ?? 0)
        case .image:      content = .image(caption: caption)
        case .link:
            if let url = url.flatMap(URL.init(string:)) {
                content = .link(url: url, title: title, summary: summary)
            } else {
                content = .text([title, summary, url].compactMap { $0 }.joined(separator: "\n"))
            }
        case .screenshot: content = .screenshot(ocrText: screenshotText)
        case .location:   content = .location(name: place?.name, latitude: place?.latitude ?? 0, longitude: place?.longitude ?? 0)
        }
        var memory = Memory(
            id: id,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            tags: tags.map { Tag(name: $0, origin: .user) },
            surfaceDate: sealedUntil,
            isLetter: isLetter
        )
        memory.ai.extractedPeople = people
        memory.ai.extractedLocations = places
        memory.ai.extractedDates = mentionedDates
        return memory
    }
}

extension ExportedTask {
    func restoredTask() -> MemoryTask {
        MemoryTask(
            id: id,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            dueDate: dueDate,
            linkedMemoryID: linkedMemoryID,
            createdAt: createdAt,
            completedAt: completedAt,
            promisedTo: promisedTo,
            cue: restoredCue
        )
    }
}
