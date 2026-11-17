import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence
import OrbitDomain

/// A store written by an unreleased 2.0 build (an earlier shape of V2)
/// matches no version in the migration plan. The app must still open it
/// and keep every row, instead of stopping at the recovery screen.
extension StoreBackedTests {
    @Suite("Interim store recovery", .serialized)
    struct InterimStoreRecoveryTests {
        private let memoryID = UUID()
        private let trashedID = UUID()
        private let taskID = UUID()
        private let created = Date(timeIntervalSince1970: 1_750_000_000)
        private let deleted = Date(timeIntervalSince1970: 1_750_100_000)

        private func writeInterimStore() throws -> URL {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("orbit-interim-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("orbit.sqlite")

            let schema = Schema(versionedSchema: OrbitSchemaInterim.self)
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let memory = OrbitSchemaInterim.MemoryEntity(id: memoryID)
            memory.textContent = "Call the bank about the new card"
            memory.createdAt = created
            memory.updatedAt = created
            context.insert(memory)

            let trashed = OrbitSchemaInterim.MemoryEntity(id: trashedID)
            trashed.textContent = "Old grocery list"
            trashed.createdAt = created
            trashed.updatedAt = created
            trashed.deletedAt = deleted
            context.insert(trashed)

            context.insert(OrbitSchemaInterim.MemoryTaskEntity(id: taskID, title: "Call the bank", createdAt: created))
            try context.save()
            return url
        }

        @Test func interimStoreOpensWithEveryRow() throws {
            let url = try writeInterimStore()
            let context = ModelContext(try ModelContainerFactory.makeContainer(mode: .storeURL(url)))

            let memories = try context.fetch(FetchDescriptor<MemoryEntity>())
            #expect(Set(memories.map(\.id)) == [memoryID, trashedID])

            let memory = try #require(memories.first(where: { $0.id == memoryID }))
            #expect(memory.textContent == "Call the bank about the new card")
            #expect(memory.createdAt == created)
            #expect(memory.deletedAt == nil)
            #expect(memory.transcriptSegmentsJSON == nil)

            // A field the interim build already had keeps its value.
            let trashed = try #require(memories.first(where: { $0.id == trashedID }))
            #expect(trashed.deletedAt == deleted)

            let tasks = try context.fetch(FetchDescriptor<MemoryTaskEntity>())
            #expect(tasks.map(\.id) == [taskID])
            #expect(tasks.first?.promisedTo == nil)
        }

        @Test func recoveredStoreReopensNormally() throws {
            let url = try writeInterimStore()
            _ = try ModelContainerFactory.makeContainer(mode: .storeURL(url))
            // Second launch: the store now matches the current schema.
            let context = ModelContext(try ModelContainerFactory.makeContainer(mode: .storeURL(url)))
            #expect(try context.fetchCount(FetchDescriptor<MemoryEntity>()) == 2)
        }
    }
}
