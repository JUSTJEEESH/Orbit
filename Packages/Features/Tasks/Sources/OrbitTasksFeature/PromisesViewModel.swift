import Foundation
import Observation
import OrbitDomain
import OrbitKit
import os

/// Drives the Promises section of Tasks: what you said you'd do for other
/// people. Noticed promises wait for a tap ("Keep" or "Not a promise");
/// kept ones behave like tasks, labeled with who they're for.
@MainActor
@Observable
public final class PromisesViewModel {
    public private(set) var ledger = PromiseLedger(suggestions: [], open: [], kept: [])
    public private(set) var errorMessage: String?

    private let loadLedger: LoadPromiseLedgerUseCase
    private let keepUseCase: KeepPromiseUseCase
    private let toggleTask: ToggleTaskUseCase
    private let dismissals: any PromiseDismissalStore
    /// Same hook as `TasksViewModel`: keeps Reminders, Calendar and local
    /// notifications in step when a promise becomes a task or is closed.
    private let onTaskMutated: @MainActor @Sendable (MemoryTask) async -> Void

    public init(
        load: LoadPromiseLedgerUseCase,
        keep: KeepPromiseUseCase,
        toggleTask: ToggleTaskUseCase,
        dismissals: any PromiseDismissalStore,
        onTaskMutated: @escaping @MainActor @Sendable (MemoryTask) async -> Void = { _ in }
    ) {
        self.loadLedger = load
        self.keepUseCase = keep
        self.toggleTask = toggleTask
        self.dismissals = dismissals
        self.onTaskMutated = onTaskMutated
    }

    public var isEmpty: Bool {
        ledger.suggestions.isEmpty && ledger.open.isEmpty && ledger.kept.isEmpty
    }

    public func refresh() async {
        do {
            ledger = try await loadLedger(dismissed: dismissals.dismissedIDs())
            errorMessage = nil
        } catch {
            OrbitLog.app.error("Promise ledger load failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't load your promises. Try again in a moment."
        }
    }

    public func keep(_ suggestion: PromiseLedger.Suggestion) async {
        do {
            let task = try await keepUseCase(suggestion)
            Haptics.play(.success)
            await onTaskMutated(task)
            await refresh()
        } catch {
            OrbitLog.app.error("Keep promise failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't save that promise."
        }
    }

    public func dismiss(_ suggestion: PromiseLedger.Suggestion) async {
        dismissals.dismiss(suggestion.id)
        ledger.suggestions.removeAll { $0.id == suggestion.id }
    }

    public func toggle(_ task: MemoryTask) async {
        do {
            if let updated = try await toggleTask(id: task.id) {
                await onTaskMutated(updated)
            }
            await refresh()
        } catch {
            OrbitLog.app.error("Toggle promise failed: \(String(describing: error), privacy: .public)")
        }
    }
}
