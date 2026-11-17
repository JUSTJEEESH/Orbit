import Foundation
import Testing
import SwiftData
@testable import OrbitPersistence
import OrbitDomain

/// Place and person reminders survive a save and reload through the real
/// SwiftData store.
extension StoreBackedTests {
    @Suite("Task cue round trip", .serialized)
    struct TaskCueRoundTripTests {
        private func makeRepository() throws -> SwiftDataTaskRepository {
            SwiftDataTaskRepository(modelContainer: try ModelContainerFactory.makeContainer(mode: .inMemory))
        }

        @Test func placeCueRoundTrips() async throws {
            let repository = try makeRepository()
            let place = PlaceCue(name: "Mom's", latitude: 30.2672, longitude: -97.7431, radius: 200)
            let task = MemoryTask(title: "Grab the ladder", createdAt: Date(timeIntervalSince1970: 1_780_000_000), cue: .place(place))
            try await repository.save(task)
            let loaded = try #require(try await repository.task(with: task.id))
            #expect(loaded.cue == .place(place))
        }

        @Test func personCueRoundTrips() async throws {
            let repository = try makeRepository()
            let task = MemoryTask(title: "Ask about the trip", createdAt: Date(timeIntervalSince1970: 1_780_000_000), cue: .person("Alex"))
            try await repository.save(task)
            #expect(try await repository.task(with: task.id)?.cue == .person("Alex"))
        }

        @Test func clearingTheCuePersists() async throws {
            let repository = try makeRepository()
            var task = MemoryTask(title: "Ask about the trip", createdAt: Date(timeIntervalSince1970: 1_780_000_000), cue: .person("Alex"))
            try await repository.save(task)
            task.cue = nil
            try await repository.update(task)
            #expect(try await repository.task(with: task.id)?.cue == nil)
        }
    }
}
