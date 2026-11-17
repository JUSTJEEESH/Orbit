import Foundation

/// Joins the task hints sitting on each memory's `signals` with the open
/// task list, returning only the hints the user hasn't yet promoted. The
/// Tasks UI renders these as one-tap "Add" cards above the actual task
/// list.
public struct ListTaskSuggestionsUseCase: Sendable {
    public struct Suggestion: Sendable, Hashable, Identifiable {
        public let memory: Memory
        public let hint: TaskHint
        public var id: UUID { hint.id }
    }

    private let memories: any MemoryRepository
    private let tasks: any TaskRepository

    public init(memories: any MemoryRepository, tasks: any TaskRepository) {
        self.memories = memories
        self.tasks = tasks
    }

    public func callAsFunction() async throws -> [Suggestion] {
        async let memoriesTask = memories.list(filter: .all)
        async let tasksTask = tasks.allTasks()
        let (allMemories, allTasks) = try await (memoriesTask, tasksTask)

        let promotedHintIDs = Set(allTasks.compactMap(\.sourceHintID))

        let suggestions: [Suggestion] = allMemories.flatMap { memory in
            // "Remind me to buy batteries when I get to Costco" is offered
            // as a place reminder; don't also offer it as a plain task.
            let cueActions = CueParser.cues(in: memory.analyzableText, memoryID: memory.id)
                .map { $0.action.lowercased() }
            return memory.ai.signals.taskHints
                .filter { !promotedHintIDs.contains($0.id) }
                .filter { hint in !cueActions.contains { hint.phrase.lowercased().hasPrefix($0) } }
                .map { Suggestion(memory: memory, hint: $0) }
        }
        // Newest memories first, so the suggestion the user just captured
        // sits at the top of the surface.
        return suggestions.sorted { $0.memory.createdAt > $1.memory.createdAt }
    }
}
