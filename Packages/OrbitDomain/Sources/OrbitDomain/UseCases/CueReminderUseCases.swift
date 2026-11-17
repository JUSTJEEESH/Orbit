import Foundation

/// Place and person reminders noticed in memories and not yet kept.
public struct ListCueSuggestionsUseCase: Sendable {
    public struct Suggestion: Sendable, Hashable, Identifiable {
        public let memory: Memory
        public let hint: CueHint
        public var id: UUID { hint.id }

        public init(memory: Memory, hint: CueHint) {
            self.memory = memory
            self.hint = hint
        }
    }

    private let memories: any MemoryRepository
    private let tasks: any TaskRepository

    public init(memories: any MemoryRepository, tasks: any TaskRepository) {
        self.memories = memories
        self.tasks = tasks
    }

    /// - Parameter dismissed: hint IDs the user waved away.
    public func callAsFunction(dismissed: Set<UUID> = []) async throws -> [Suggestion] {
        async let memoriesTask = memories.list(filter: MemoryFilter(sort: .newestFirst))
        async let tasksTask = tasks.allTasks()
        let (all, allTasks) = try await (memoriesTask, tasksTask)
        let kept = Set(allTasks.compactMap(\.sourceHintID))
        return all.flatMap { memory in
            CueParser.cues(in: memory.analyzableText, memoryID: memory.id)
                .filter { !kept.contains($0.id) && !dismissed.contains($0.id) }
                .map { Suggestion(memory: memory, hint: $0) }
        }
    }
}

/// Keeps a noticed cue as a task. Place cues need coordinates, which the
/// user confirms (current location or a Maps result) before this runs.
public struct KeepCueReminderUseCase: Sendable {
    public enum KeepError: Error, Sendable {
        /// A place cue was kept without a confirmed location.
        case placeNotResolved
    }

    private let tasks: any TaskRepository
    private let clock: any OrbitClock

    public init(tasks: any TaskRepository, clock: any OrbitClock) {
        self.tasks = tasks
        self.clock = clock
    }

    @discardableResult
    public func callAsFunction(_ suggestion: ListCueSuggestionsUseCase.Suggestion, place: PlaceCue? = nil) async throws -> MemoryTask {
        let cue: TaskCue
        switch suggestion.hint.target {
        case .place:
            guard let place else { throw KeepError.placeNotResolved }
            cue = .place(place)
        case .person(let name):
            cue = .person(name)
        }
        let action = suggestion.hint.action
        let task = MemoryTask(
            title: action.prefix(1).uppercased() + action.dropFirst(),
            linkedMemoryID: suggestion.memory.id,
            sourceHintID: suggestion.hint.id,
            createdAt: clock.now(),
            cue: cue
        )
        try await tasks.save(task)
        return task
    }
}
