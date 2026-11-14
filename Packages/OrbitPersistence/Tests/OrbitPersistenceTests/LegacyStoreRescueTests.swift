import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence
import OrbitDomain

@Suite("Legacy store rescue", .serialized)
struct LegacyStoreRescueTests {

    private func makeStoreURL(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-rescue-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    /// A 1.x per-app store holding one Siri capture and one task, written
    /// with the frozen V1 schema exactly as 1.x's intent wrote it.
    private func writeLegacyV1Store(at url: URL, memoryID: UUID, taskID: UUID) throws {
        let schema = Schema(versionedSchema: OrbitSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let memory = OrbitSchemaV1.MemoryEntity(id: memoryID)
        memory.contentKind = "text"
        memory.textContent = "Remember to email Sam about the invoice"
        memory.createdAt = Date(timeIntervalSince1970: 1_750_000_000)
        context.insert(memory)
        context.insert(OrbitSchemaV1.MemoryTaskEntity(id: taskID, title: "Email Sam"))
        try context.save()
    }

    private func repositories(at url: URL) throws -> (SwiftDataMemoryRepository, SwiftDataTaskRepository) {
        let container = try ModelContainerFactory.makeContainer(mode: .storeURL(url))
        return (SwiftDataMemoryRepository(modelContainer: container), SwiftDataTaskRepository(modelContainer: container))
    }

    @Test func copiesHiddenSiriCapturesIntoMainLibrary() async throws {
        let legacyURL = try makeStoreURL("orbit-local.store")
        let memoryID = UUID()
        let taskID = UUID()
        try writeLegacyV1Store(at: legacyURL, memoryID: memoryID, taskID: taskID)

        let (legacyMemories, legacyTasks) = try repositories(at: legacyURL)
        let (mainMemories, mainTasks) = try repositories(at: try makeStoreURL("orbit.sqlite"))
        let existing = Memory(content: .text("Already in the library"), createdAt: .now, updatedAt: .now)
        try await mainMemories.save(existing)

        let outcome = try await LegacyStoreRescue.copyMissingRows(
            fromMemories: legacyMemories, tasks: legacyTasks,
            intoMemories: mainMemories, tasks: mainTasks
        )

        #expect(outcome.rescuedMemoryIDs == [memoryID])
        #expect(outcome.rescuedTaskIDs == [taskID])
        let rescued = try #require(try await mainMemories.memory(with: memoryID))
        #expect(rescued.content == .text("Remember to email Sam about the invoice"))
        #expect(rescued.createdAt == Date(timeIntervalSince1970: 1_750_000_000))
        #expect(try await mainTasks.task(with: taskID)?.title == "Email Sam")
        #expect(try await mainMemories.list(filter: .allIncludingSealed).count == 2)

        // The legacy store keeps its rows: rescue copies, never moves.
        #expect(try await legacyMemories.memory(with: memoryID) != nil)
    }

    @Test func runningTwiceCopiesNothingNew() async throws {
        let legacyURL = try makeStoreURL("orbit-local.store")
        try writeLegacyV1Store(at: legacyURL, memoryID: UUID(), taskID: UUID())
        let (legacyMemories, legacyTasks) = try repositories(at: legacyURL)
        let (mainMemories, mainTasks) = try repositories(at: try makeStoreURL("orbit.sqlite"))

        _ = try await LegacyStoreRescue.copyMissingRows(
            fromMemories: legacyMemories, tasks: legacyTasks, intoMemories: mainMemories, tasks: mainTasks
        )
        let second = try await LegacyStoreRescue.copyMissingRows(
            fromMemories: legacyMemories, tasks: legacyTasks, intoMemories: mainMemories, tasks: mainTasks
        )

        #expect(second.isEmpty)
        #expect(try await mainMemories.list(filter: .allIncludingSealed).count == 1)
        #expect(try await mainTasks.allTasks().count == 1)
    }

    /// If the App Group was unavailable, the main library *is* the per-app
    /// store. Rescuing a store into itself must be a no-op.
    @Test func rescuingAStoreIntoItselfIsANoOp() async throws {
        let url = try makeStoreURL("orbit-local.store")
        try writeLegacyV1Store(at: url, memoryID: UUID(), taskID: UUID())
        let (memories, tasks) = try repositories(at: url)

        let outcome = try await LegacyStoreRescue.copyMissingRows(
            fromMemories: memories, tasks: tasks, intoMemories: memories, tasks: tasks
        )

        #expect(outcome.isEmpty)
        #expect(try await memories.list(filter: .allIncludingSealed).count == 1)
    }

    @Test func reportsMediaFilenamesOfRescuedMemories() async throws {
        let source = InMemoryMemoryRepository()
        let asset = MediaAsset(kind: .audio, filename: "abc.wav", byteSize: 10, createdAt: .now)
        try await source.save(Memory(content: .voiceNote(transcript: nil, duration: 3), createdAt: .now, updatedAt: .now, media: [asset]))

        let outcome = try await LegacyStoreRescue.copyMissingRows(
            fromMemories: source, tasks: InMemoryTaskRepository(),
            intoMemories: InMemoryMemoryRepository(), tasks: InMemoryTaskRepository()
        )
        #expect(outcome.mediaFilenames == ["abc.wav"])
    }
}
