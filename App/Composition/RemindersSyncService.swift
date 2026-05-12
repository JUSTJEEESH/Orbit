import Foundation
import EventKit
import UIKit
import Observation
import OrbitDomain
import OrbitKit

/// Two-way mirror between Orbit tasks and iOS Reminders. When sync is on,
/// every `MemoryTask` mutation propagates to a matching `EKReminder`, and
/// any change made in the Reminders app (or via Siri / CarPlay / shortcuts)
/// is pulled back into Orbit when the app returns to the foreground.
///
/// Side-effect-only: `TasksViewModel` calls into this service after each
/// mutation, but doesn't depend on EventKit itself. If the user has sync
/// disabled or hasn't granted permission, every mirror call silently no-ops.
@MainActor
@Observable
public final class RemindersSyncService {
    private static let enabledKey = "orbit.reminders.sync.enabled"

    public private(set) var isEnabled: Bool
    public private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private let store = EKEventStore()
    private let tasks: any TaskRepository

    public init(tasks: any TaskRepository) {
        self.tasks = tasks
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    public var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    /// Asks iOS for full reminders access. Returns true if granted. Callers
    /// should refresh the toggle UI from the resulting `isEnabled` —
    /// a denial silently flips sync back off so the user's switch matches
    /// reality.
    @discardableResult
    public func enable() async -> Bool {
        if !isAuthorized {
            do {
                _ = try await store.requestFullAccessToReminders()
            } catch {
                OrbitLog.app.error("Reminders auth request failed: \(String(describing: error), privacy: .public)")
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        }

        guard isAuthorized else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return false
        }

        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)

        // Mirror everything we already have so the user's existing tasks
        // show up in Reminders the moment they flip the switch on.
        await mirrorAllTasks()
        return true
    }

    /// Flips sync off without revoking iOS-level permission or deleting
    /// existing mirrored reminders. The user can re-enable later and
    /// reconnect to the same reminders by identifier.
    public func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
    }

    public func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Mutation mirror

    /// Mirrors a single task into Reminders — creating the EKReminder on
    /// first call, then updating it on every subsequent call. Persists the
    /// new identifier back to the task repository so the link survives a
    /// relaunch.
    public func mirror(_ task: MemoryTask) async {
        guard isEnabled, isAuthorized else { return }
        guard let calendar = defaultCalendar() else { return }

        let reminder: EKReminder
        if let identifier = task.remindersIdentifier,
           let existing = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder = existing
        } else {
            reminder = EKReminder(eventStore: store)
            reminder.calendar = calendar
        }

        reminder.title = task.title
        reminder.notes = task.notes
        reminder.isCompleted = task.isCompleted
        reminder.dueDateComponents = task.dueDate.map { Self.makeDueComponents(from: $0) }

        do {
            try store.save(reminder, commit: true)
            if task.remindersIdentifier != reminder.calendarItemIdentifier {
                var updated = task
                updated.remindersIdentifier = reminder.calendarItemIdentifier
                try? await tasks.update(updated)
            }
        } catch {
            OrbitLog.app.error("Mirror to Reminders failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Tears down the EKReminder behind a task — fire when the user deletes
    /// the Orbit task. We swallow lookup failures because the user might
    /// have already deleted the reminder manually.
    public func removeMirror(for task: MemoryTask) async {
        guard let identifier = task.remindersIdentifier else { return }
        guard isAuthorized else { return }
        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        do {
            try store.remove(reminder, commit: true)
        } catch {
            OrbitLog.app.error("Remove mirror failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Read-back

    /// Foreground hook: walks every task with a mirrored reminder and copies
    /// completion-state changes back into the Orbit repository. Acts as the
    /// "user completed it from the Reminders app / Siri" path.
    public func pullCompletionUpdates() async {
        guard isEnabled, isAuthorized else { return }
        let all = (try? await tasks.allTasks()) ?? []
        for task in all where task.remindersIdentifier != nil {
            guard let identifier = task.remindersIdentifier,
                  let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder
            else { continue }
            if reminder.isCompleted != task.isCompleted {
                var updated = task
                updated.isCompleted = reminder.isCompleted
                updated.completedAt = reminder.isCompleted ? (reminder.completionDate ?? Date()) : nil
                try? await tasks.update(updated)
            }
        }
    }

    // MARK: - Helpers

    private func mirrorAllTasks() async {
        let all = (try? await tasks.allTasks()) ?? []
        for task in all {
            await mirror(task)
        }
    }

    /// The default Reminders calendar. May be `nil` if the user has no
    /// Reminders calendars at all (rare, but EventKit allows it).
    private func defaultCalendar() -> EKCalendar? {
        store.defaultCalendarForNewReminders()
    }

    /// Converts a `Date` to the day-and-time components Reminders expects.
    /// Reminders treats a `dueDateComponents` value with hour/minute as an
    /// alarm-time; we keep both so the user gets the iOS reminder bell at
    /// the time they picked in Orbit.
    private static func makeDueComponents(from date: Date) -> DateComponents {
        Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
    }
}
