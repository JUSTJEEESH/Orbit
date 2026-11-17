import Foundation
import Testing
@testable import OrbitPersistence
import OrbitDomain

@Suite("Library import")
struct LibraryImporterTests {

    private func write(_ contents: String, named name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private let dayOneJSON = """
    {
      "metadata": { "version": "1.0" },
      "entries": [
        {
          "uuid": "0F3C2B1A9E8D4C7B6A5F4E3D2C1B0A99",
          "creationDate": "2024-03-02T14:30:00Z",
          "text": "Found a tiny bookshop on Calle 8\\\\. ![](dayone-moment://ABC)",
          "tags": ["travel", "books"],
          "location": { "placeName": "Calle 8", "latitude": 25.76, "longitude": -80.19 }
        },
        { "uuid": "11111111111111111111111111111111", "creationDate": "2024-03-03T09:00:00Z", "text": "   " }
      ]
    }
    """

    @Test func importsDayOneEntries() async throws {
        let url = try write(dayOneJSON, named: "Journal.json")
        let memories = InMemoryMemoryRepository()

        let summary = try await LibraryImporter.importFiles([url], memories: memories, tasks: InMemoryTaskRepository())

        #expect(summary.importedMemories == 1)
        let imported = try #require(try await memories.list(filter: .all).first)
        #expect(imported.content == .text("Found a tiny bookshop on Calle 8."))
        #expect(imported.createdAt == ISO8601DateFormatter().date(from: "2024-03-02T14:30:00Z"))
        #expect(imported.tags.map(\.name) == ["travel", "books"])
        #expect(imported.ai.extractedLocations == ["Calle 8"])
        #expect(imported.id == UUID(uuidString: "0F3C2B1A-9E8D-4C7B-6A5F-4E3D2C1B0A99"))
    }

    @Test func importingTwiceSkipsDuplicates() async throws {
        let url = try write(dayOneJSON, named: "Journal.json")
        let memories = InMemoryMemoryRepository()
        let tasks = InMemoryTaskRepository()

        _ = try await LibraryImporter.importFiles([url], memories: memories, tasks: tasks)
        let second = try await LibraryImporter.importFiles([url], memories: memories, tasks: tasks)

        #expect(second.importedMemories == 0)
        #expect(second.skippedDuplicates == 1)
        #expect(try await memories.list(filter: .all).count == 1)
    }

    @Test func restoresOrbitExportRoundTrip() async throws {
        let original = Memory(
            content: .voiceNote(transcript: "Bookshop idea", duration: 12),
            createdAt: Date(timeIntervalSince1970: 1_750_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_750_000_100),
            tags: [Tag(name: "ideas")]
        )
        let task = MemoryTask(title: "Visit bookshop", dueDate: Date(timeIntervalSince1970: 1_760_000_000), createdAt: Date(timeIntervalSince1970: 1_750_000_000))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("orbit-roundtrip-\(UUID().uuidString)")
        try await LibraryExporter.writeExport(
            to: folder,
            memories: InMemoryMemoryRepository(seed: [original]),
            tasks: InMemoryTaskRepository(seed: [task]),
            mediaURL: { URL(fileURLWithPath: "/missing/\($0)") },
            fileManager: .default, now: .now
        )

        let memories = InMemoryMemoryRepository()
        let tasks = InMemoryTaskRepository()
        let summary = try await LibraryImporter.importFiles(
            [folder.appendingPathComponent("orbit.json")], memories: memories, tasks: tasks
        )

        #expect(summary.importedMemories == 1)
        #expect(summary.importedTasks == 1)
        let restored = try #require(try await memories.memory(with: original.id))
        #expect(restored.content == original.content)
        #expect(restored.createdAt == original.createdAt)
        #expect(restored.tags.map(\.name) == ["ideas"])
        #expect(try await tasks.task(with: task.id)?.title == "Visit bookshop")
    }

    @Test func importsTextFileAsOneMemory() async throws {
        let url = try write("# Packing list\nPassport, charger", named: "Packing.md")
        let memories = InMemoryMemoryRepository()

        let summary = try await LibraryImporter.importFiles([url], memories: memories, tasks: InMemoryTaskRepository())

        #expect(summary.importedMemories == 1)
        #expect(try await memories.list(filter: .all).first?.content == .text("# Packing list\nPassport, charger"))
    }

    @Test func unreadableFileIsCountedNotFatal() async throws {
        let url = try write("{ not json", named: "broken.json")
        let summary = try await LibraryImporter.importFiles([url], memories: InMemoryMemoryRepository(), tasks: InMemoryTaskRepository())
        #expect(summary.unreadableFiles == 1)
    }

    @Test func promiseSurvivesExportAndRestore() throws {
        let task = MemoryTask(title: "Send the photos", createdAt: Date(timeIntervalSince1970: 1_750_000_000), promisedTo: "Sam")
        let data = try JSONEncoder().encode(ExportedTask(task))
        let restored = try JSONDecoder().decode(ExportedTask.self, from: data).restoredTask()
        #expect(restored.promisedTo == "Sam")
    }

    @Test func remindersSurviveExportAndRestore() throws {
        let created = Date(timeIntervalSince1970: 1_750_000_000)
        let place = PlaceCue(name: "Mom's", latitude: 30.2672, longitude: -97.7431)
        for cue in [TaskCue.place(place), .person("Alex")] {
            let task = MemoryTask(title: "Grab the ladder", createdAt: created, cue: cue)
            let data = try JSONEncoder().encode(ExportedTask(task))
            #expect(try JSONDecoder().decode(ExportedTask.self, from: data).restoredTask().cue == cue)
        }
    }

    @Test func taskExportedBefore2_0StillDecodes() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","title":"Buy milk","isCompleted":false,"createdAt":0}
        """
        let task = try JSONDecoder().decode(ExportedTask.self, from: Data(legacy.utf8)).restoredTask()
        #expect(task.title == "Buy milk")
        #expect(task.promisedTo == nil)
        #expect(task.cue == nil)
    }
}
