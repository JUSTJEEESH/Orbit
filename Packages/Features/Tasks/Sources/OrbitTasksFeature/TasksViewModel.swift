import Foundation
import Observation
import OrbitDomain
import OrbitKit

/// Pulls the full task list + suggestion list and slices it into the
/// sections the Tasks UI renders. Updates re-fetch via a refresh token so a
/// completion or promotion immediately propagates without the view having
/// to mutate the model itself.
@MainActor
@Observable
public final class TasksViewModel {
    public struct Sections: Equatable, Sendable {
        public var soon: [MemoryTask]      // due in the next 7 days (incl. overdue)
        public var open: [MemoryTask]      // open, no due date or due >7 days out
        public var completed: [MemoryTask] // most recent first
    }

    public private(set) var suggestions: [ListTaskSuggestionsUseCase.Suggestion] = []
    public private(set) var sections: Sections = Sections(soon: [], open: [], completed: [])
    public private(set) var memoriesByID: [UUID: Memory] = [:]
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    private let listTasks: ListTasksUseCase
    private let listSuggestions: ListTaskSuggestionsUseCase
    private let promoteUseCase: PromoteHintToTaskUseCase
    private let toggleTask: ToggleTaskUseCase
    private let updateTaskUseCase: UpdateTaskUseCase
    private let deleteTaskUseCase: DeleteTaskUseCase
    private let memories: any MemoryRepository
    private let clock: any OrbitClock
    /// Fired after a create / update / toggle persists. RootView wires this
    /// into `RemindersSyncService.mirror(_:)` so iOS Reminders stays in
    /// step without OrbitTasksFeature having to know EventKit exists.
    private let onTaskMutated: @MainActor @Sendable (MemoryTask) async -> Void
    /// Fired after a delete persists; receives the full task value so the
    /// sync layer can tear down the mirrored reminder via its stored
    /// identifier.
    private let onTaskDeleted: @MainActor @Sendable (MemoryTask) async -> Void

    public init(
        listTasks: ListTasksUseCase,
        listSuggestions: ListTaskSuggestionsUseCase,
        promote: PromoteHintToTaskUseCase,
        toggleTask: ToggleTaskUseCase,
        updateTaskUseCase: UpdateTaskUseCase,
        deleteTaskUseCase: DeleteTaskUseCase,
        memories: any MemoryRepository,
        clock: any OrbitClock,
        onTaskMutated: @escaping @MainActor @Sendable (MemoryTask) async -> Void = { _ in },
        onTaskDeleted: @escaping @MainActor @Sendable (MemoryTask) async -> Void = { _ in }
    ) {
        self.listTasks = listTasks
        self.listSuggestions = listSuggestions
        self.promoteUseCase = promote
        self.toggleTask = toggleTask
        self.updateTaskUseCase = updateTaskUseCase
        self.deleteTaskUseCase = deleteTaskUseCase
        self.memories = memories
        self.clock = clock
        self.onTaskMutated = onTaskMutated
        self.onTaskDeleted = onTaskDeleted
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let allTasks = listTasks()
            async let suggestionsTask = listSuggestions()
            let (tasks, suggestions) = try await (allTasks, suggestionsTask)

            self.suggestions = suggestions
            self.sections = slice(tasks: tasks)

            // Fetch the linked-memory snippets in one pass so each task row
            // can render "From: <headline>" without N round trips.
            let ids = Set(
                tasks.compactMap(\.linkedMemoryID)
                + suggestions.map(\.memory.id)
            )
            var lookup: [UUID: Memory] = [:]
            for memory in suggestions.map(\.memory) {
                lookup[memory.id] = memory
            }
            for id in ids where lookup[id] == nil {
                if let memory = try? await memories.memory(with: id) {
                    lookup[id] = memory
                }
            }
            self.memoriesByID = lookup
            self.errorMessage = nil
        } catch {
            self.errorMessage = String(describing: error)
        }
    }

    public func promote(_ suggestion: ListTaskSuggestionsUseCase.Suggestion) async {
        do {
            let task = try await promoteUseCase(memory: suggestion.memory, hint: suggestion.hint)
            Haptics.play(.success)
            await load()
            await onTaskMutated(task)
        } catch {
            errorMessage = String(describing: error)
            Haptics.play(.failure)
        }
    }

    public func toggle(_ task: MemoryTask) async {
        do {
            let updated = try await toggleTask(id: task.id)
            Haptics.play(.selection)
            await load()
            if let updated {
                await onTaskMutated(updated)
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func update(_ task: MemoryTask) async {
        do {
            try await updateTaskUseCase(task)
            await load()
            await onTaskMutated(task)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    public func delete(_ task: MemoryTask) async {
        do {
            try await deleteTaskUseCase(id: task.id)
            Haptics.play(.warning)
            await load()
            await onTaskDeleted(task)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func slice(tasks: [MemoryTask]) -> Sections {
        let calendar = Calendar.current
        let now = clock.now()
        let endOfSoonWindow = calendar.date(byAdding: .day, value: 7, to: now) ?? now

        var soon: [MemoryTask] = []
        var open: [MemoryTask] = []
        var completed: [MemoryTask] = []

        for task in tasks {
            if task.isCompleted {
                completed.append(task)
                continue
            }
            if let due = task.dueDate, due <= endOfSoonWindow {
                soon.append(task)
            } else {
                open.append(task)
            }
        }

        soon.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        open.sort { $0.createdAt > $1.createdAt }
        completed.sort { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }

        return Sections(soon: soon, open: open, completed: completed)
    }
}
