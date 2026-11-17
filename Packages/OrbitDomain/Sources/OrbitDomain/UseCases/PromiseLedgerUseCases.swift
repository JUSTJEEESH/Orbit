import Foundation

/// The Promise Ledger: commitments you made to people, pulled from what you
/// captured ("I told Sam I'd send the photos"), kept until you close them.
public struct PromiseLedger: Sendable, Equatable {
    /// A promise Orbit noticed but you haven't kept in the ledger yet.
    public struct Suggestion: Sendable, Hashable, Identifiable {
        public let memory: Memory
        public let promise: PromiseHint
        public var id: UUID { promise.id }
    }

    public var suggestions: [Suggestion]
    /// Kept promises still open, soonest due first.
    public var open: [MemoryTask]
    /// Kept promises you've closed, most recent first.
    public var kept: [MemoryTask]
}

public struct LoadPromiseLedgerUseCase: Sendable {
    private let memories: any MemoryRepository
    private let tasks: any TaskRepository

    public init(memories: any MemoryRepository, tasks: any TaskRepository) {
        self.memories = memories
        self.tasks = tasks
    }

    /// - Parameter dismissed: promise IDs the user waved away.
    public func callAsFunction(dismissed: Set<UUID>) async throws -> PromiseLedger {
        let allTasks = try await tasks.allTasks()
        let keptHintIDs = Set(allTasks.compactMap(\.sourceHintID))
        let suggestions = try await memories.list(filter: .all).flatMap { memory in
            memory.ai.signals.promises
                .filter { !keptHintIDs.contains($0.id) && !dismissed.contains($0.id) }
                .map { PromiseLedger.Suggestion(memory: memory, promise: $0) }
        }
        let promised = allTasks.filter { $0.promisedTo != nil }
        return PromiseLedger(
            suggestions: suggestions,
            open: promised.filter { !$0.isCompleted }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) },
            kept: promised.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        )
    }
}

/// Moves a noticed promise into the ledger as a task promised to that person.
public struct KeepPromiseUseCase: Sendable {
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(tasks: any TaskRepository, clock: any OrbitClock) {
        self.tasks = tasks
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(_ suggestion: PromiseLedger.Suggestion) async throws -> MemoryTask {
        let task = MemoryTask(
            title: suggestion.promise.item.prefix(1).uppercased() + suggestion.promise.item.dropFirst(),
            dueDate: suggestion.promise.dueDate,
            linkedMemoryID: suggestion.memory.id,
            sourceHintID: suggestion.promise.id,
            createdAt: clock.now(),
            promisedTo: suggestion.promise.person
        )
        try await tasks.save(task)
        return task
    }
}
