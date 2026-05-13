import Foundation

public struct ReminderSuggestion: Sendable, Hashable, Identifiable {
    public let memory: Memory
    public let date: Date
    public var id: UUID { memory.id }

    public init(memory: Memory, date: Date) {
        self.memory = memory
        self.date = date
    }
}

/// Surfaces memories that carry a future date in `ai.extractedDates` but
/// haven't been turned into a task yet. The Tasks UI offers a one-tap
/// "Set a reminder" affordance that promotes the suggestion into a real
/// MemoryTask with that date as its due-date.
///
/// Sorted by the earliest future date so the soonest things rise to the
/// top — premium reminder surfaces respect the user's calendar instinct.
public struct ListReminderSuggestionsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(
        memories: any MemoryRepository,
        tasks: any TaskRepository,
        clock: any OrbitClock
    ) {
        self.memories = memories
        self.tasks = tasks
        self.clock = clock
    }

    public func callAsFunction() async throws -> [ReminderSuggestion] {
        let now = clock.now()
        async let memoriesTask = memories.list(filter: .all)
        async let tasksTask = tasks.allTasks()
        let (allMemories, allTasks) = try await (memoriesTask, tasksTask)
        let memoryIDsWithTasks = Set(allTasks.compactMap(\.linkedMemoryID))

        return allMemories.compactMap { memory -> ReminderSuggestion? in
            // Skip memories that have already been promoted into a task —
            // the suggestion would compete with the live task row.
            guard !memoryIDsWithTasks.contains(memory.id) else { return nil }
            let futureDates = memory.ai.extractedDates.filter { $0 > now }
            guard let earliest = futureDates.min() else { return nil }
            return ReminderSuggestion(memory: memory, date: earliest)
        }
        .sorted { $0.date < $1.date }
    }
}
