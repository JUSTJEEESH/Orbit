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
    /// Human-readable description of the last sync failure, surfaced in
    /// Settings → Reminders. Silent failures (no Reminders calendar,
    /// permission revoked, EKEventStore save error) used to be invisible
    /// to the user, which made misconfigured iCloud setups feel like
    /// "Orbit is broken." This is the breadcrumb.
    public private(set) var lastError: String?

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
        lastError = nil
        if !isAuthorized {
            do {
                let granted = try await store.requestFullAccessToReminders()
                authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
                if !granted {
                    isEnabled = false
                    UserDefaults.standard.set(false, forKey: Self.enabledKey)
                    OrbitLog.app.notice("Reminders permission declined.")
                    return false
                }
            } catch {
                OrbitLog.app.error("Reminders auth request failed: \(String(describing: error), privacy: .public)")
                lastError = "Couldn't reach Reminders. Try again from Settings."
                isEnabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                return false
            }
        }

        guard isAuthorized else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return false
        }

        // Confirm we have at least one writeable Reminders calendar before
        // flipping the toggle on. If the user has no iCloud Reminders set
        // up (common on simulators + fresh devices) `defaultCalendar()`
        // would return nil and every later mirror would silently no-op.
        guard let calendar = defaultCalendar() else {
            lastError = "No Reminders list available. Open the Reminders app once to create one, then try again."
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            OrbitLog.app.notice("Reminders sync skipped: no available Reminders calendar.")
            return false
        }
        OrbitLog.app.notice("Reminders sync ready. Calendar: \(calendar.title, privacy: .public).")

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
        guard isEnabled else { return }
        guard isAuthorized else {
            lastError = "Reminders access isn't granted. Re-enable in iOS Settings."
            return
        }
        guard let calendar = defaultCalendar() else {
            lastError = "No Reminders list available. Open the Reminders app once to create one."
            OrbitLog.app.notice("Mirror skipped: no available Reminders calendar.")
            return
        }

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
            lastError = nil
            OrbitLog.app.notice("Mirrored task to Reminders: \(reminder.title ?? "(untitled)", privacy: .public).")
            if task.remindersIdentifier != reminder.calendarItemIdentifier {
                var updated = task
                updated.remindersIdentifier = reminder.calendarItemIdentifier
                try? await tasks.update(updated)
            }
        } catch {
            OrbitLog.app.error("Mirror to Reminders failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't save to Reminders. Try again."
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

    /// The Reminders calendar Orbit writes into. Tries the user's default
    /// first; falls back to the first writeable Reminders calendar in the
    /// store. Returns nil only when the user truly has zero Reminders
    /// lists — a state Settings surfaces as actionable feedback.
    private func defaultCalendar() -> EKCalendar? {
        if let preferred = store.defaultCalendarForNewReminders(), preferred.allowsContentModifications {
            return preferred
        }
        return store.calendars(for: .reminder)
            .first(where: { $0.allowsContentModifications })
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
