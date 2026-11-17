import Foundation
import Testing
@testable import OrbitDomain

@Suite("Promise Ledger")
struct PromiseLedgerTests {
    private func memory(with promise: PromiseHint) -> Memory {
        var memory = Memory(content: .text("I told \(promise.person) I'd \(promise.item)"), createdAt: .now, updatedAt: .now)
        memory.ai.signals = ExtractedSignals(promises: [promise])
        return memory
    }

    @Test func noticedPromisesAppearUntilKeptOrDismissed() async throws {
        let photos = PromiseHint(person: "Sam", item: "send the photos")
        let coffee = PromiseHint(person: "Alex", item: "a coffee")
        let memories = InMemoryMemoryRepository(seed: [memory(with: photos), memory(with: coffee)])
        let tasks = InMemoryTaskRepository()
        let load = LoadPromiseLedgerUseCase(memories: memories, tasks: tasks)

        #expect(Set(try await load(dismissed: []).suggestions.map(\.id)) == [photos.id, coffee.id])

        let initial = try await load(dismissed: [])
        let suggestion = try #require(initial.suggestions.first(where: { $0.id == photos.id }))
        let task = try await KeepPromiseUseCase(tasks: tasks, clock: SystemClock())(suggestion)
        #expect(task.promisedTo == "Sam")
        #expect(task.title == "Send the photos")

        let ledger = try await load(dismissed: [coffee.id])
        #expect(ledger.suggestions.isEmpty)
        #expect(ledger.open.map(\.id) == [task.id])
    }

    @Test func closedPromisesMoveToKept() async throws {
        let done = MemoryTask(title: "Send the photos", isCompleted: true, createdAt: .now, completedAt: .now, promisedTo: "Sam")
        let plainTask = MemoryTask(title: "Buy milk", createdAt: .now)
        let ledger = try await LoadPromiseLedgerUseCase(
            memories: InMemoryMemoryRepository(),
            tasks: InMemoryTaskRepository(seed: [done, plainTask])
        )(dismissed: [])
        #expect(ledger.kept.map(\.id) == [done.id])
        #expect(ledger.open.isEmpty)
    }
}
