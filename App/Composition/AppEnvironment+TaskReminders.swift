import Foundation
import OrbitDomain

/// Local alerts for tasks with a due date — "call mom tomorrow at 5" rings
/// tomorrow at 5. When Reminders sync is on, the Reminders app already
/// rings for mirrored tasks, so Orbit stays quiet to avoid a double alert.
extension AppEnvironment {
    private enum TaskReminder {
        /// Day-only due dates ("on Friday") ring in the morning.
        static let dayOnlyHour = 9
        /// `NSDataDetector` gives day-only dates this time of day, so a due
        /// date at exactly noon is treated as "no time given".
        static let impliedNoonHour = 12
    }

    /// Schedules, moves or cancels a task's alert to match its current state.
    func syncTaskReminder(for task: MemoryTask) async {
        guard let due = task.dueDate, !task.isCompleted, !remindersSync.isEnabled else {
            notifications.cancelTaskReminder(taskID: task.id)
            return
        }
        await notifications.scheduleTaskReminder(
            taskID: task.id,
            title: task.title,
            fireDate: Self.fireDate(for: due),
            linkedMemoryID: task.linkedMemoryID
        )
    }

    func cancelTaskReminder(for task: MemoryTask) {
        notifications.cancelTaskReminder(taskID: task.id)
    }

    static func fireDate(for due: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: due)
        let isDayOnly = parts.hour == TaskReminder.impliedNoonHour && parts.minute == 0 && parts.second == 0
        guard isDayOnly else { return due }
        return calendar.date(bySettingHour: TaskReminder.dayOnlyHour, minute: 0, second: 0, of: due) ?? due
    }
}
