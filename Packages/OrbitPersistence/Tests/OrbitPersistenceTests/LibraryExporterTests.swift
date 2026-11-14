import Foundation
import Testing
@testable import OrbitPersistence
import OrbitDomain

@Suite("Library export", .serialized)
struct LibraryExporterTests {

    private func makeFolder(_ label: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-export-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func exportContainsEveryMemoryTaskAndFile() async throws {
        let mediaRoot = try makeFolder("media")
        try Data("jpeg-bytes".utf8).write(to: mediaRoot.appendingPathComponent("photo.jpg"))

        let photo = Memory(
            content: .image(caption: "Sunset over the lake"),
            createdAt: Date(timeIntervalSince1970: 1_750_000_000), updatedAt: .now,
            tags: [Tag(name: "travel")],
            media: [MediaAsset(kind: .image, filename: "photo.jpg", byteSize: 10, createdAt: .now)]
        )
        let note = Memory(content: .text("Renew passport"), createdAt: Date(timeIntervalSince1970: 1_760_000_000), updatedAt: .now)
        let letter = Memory(
            content: .text("Dear future me"), createdAt: .now, updatedAt: .now,
            surfaceDate: Date(timeIntervalSince1970: 4_000_000_000), isLetter: true
        )
        let trashed = Memory(content: .text("deleted thing"), createdAt: .now, updatedAt: .now, deletedAt: .now)
        let memories = InMemoryMemoryRepository(seed: [photo, note, letter, trashed])
        let tasks = InMemoryTaskRepository(seed: [MemoryTask(title: "Book flights", createdAt: .now)])

        let output = try makeFolder("out")
        try await LibraryExporter.writeExport(
            to: output, memories: memories, tasks: tasks,
            mediaURL: { mediaRoot.appendingPathComponent($0) },
            fileManager: .default, now: .now
        )

        // Media copied byte-for-byte.
        let copied = try Data(contentsOf: output.appendingPathComponent("media/photo.jpg"))
        #expect(String(decoding: copied, as: UTF8.self) == "jpeg-bytes")

        // JSON: every live memory (letters included, Recently Deleted not).
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ExportDocument.self, from: Data(contentsOf: output.appendingPathComponent("orbit.json")))
        #expect(Set(document.memories.map(\.id)) == [photo.id, note.id, letter.id])
        #expect(document.tasks.map(\.title) == ["Book flights"])
        let exportedPhoto = try #require(document.memories.first { $0.id == photo.id })
        #expect(exportedPhoto.caption == "Sunset over the lake")
        #expect(exportedPhoto.tags == ["travel"])
        #expect(exportedPhoto.media == [ExportedMemory.Media(kind: "image", file: "media/photo.jpg")])
        #expect(document.memories.first { $0.id == letter.id }?.sealedUntil == Date(timeIntervalSince1970: 4_000_000_000))

        // Markdown journal mentions each memory and the task.
        let markdown = try String(contentsOf: output.appendingPathComponent("Orbit Memories.md"), encoding: .utf8)
        #expect(markdown.contains("Renew passport"))
        #expect(markdown.contains("Dear future me"))
        #expect(markdown.contains("![Photo](media/photo.jpg)"))
        #expect(markdown.contains("- [ ] Book flights"))
        #expect(!markdown.contains("deleted thing"))
    }

    @Test func missingMediaFileIsSkippedNotFatal() async throws {
        let memory = Memory(
            content: .voiceNote(transcript: "hello", duration: 4), createdAt: .now, updatedAt: .now,
            media: [MediaAsset(kind: .audio, filename: "gone.wav", byteSize: 1, createdAt: .now)]
        )
        let output = try makeFolder("out")
        try await LibraryExporter.writeExport(
            to: output, memories: InMemoryMemoryRepository(seed: [memory]), tasks: InMemoryTaskRepository(),
            mediaURL: { FileManager.default.temporaryDirectory.appendingPathComponent("nope-\($0)") },
            fileManager: .default, now: .now
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ExportDocument.self, from: Data(contentsOf: output.appendingPathComponent("orbit.json")))
        #expect(document.memories.first?.transcript == "hello")
        #expect(document.memories.first?.media.isEmpty == true)
    }

    @Test func emptyLibraryIsReported() async throws {
        await #expect(throws: LibraryExporter.ExportError.self) {
            try await LibraryExporter.writeExport(
                to: try makeFolder("out"), memories: InMemoryMemoryRepository(), tasks: InMemoryTaskRepository(),
                mediaURL: { URL(fileURLWithPath: "/\($0)") }, fileManager: .default, now: .now
            )
        }
    }
}
