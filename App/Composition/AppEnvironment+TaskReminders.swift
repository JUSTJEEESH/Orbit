import Foundation
import OrbitDomain
import OrbitKit
import os

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

    /// Schedules, moves or cancels a task's alerts to match its current state.
    func syncTaskReminder(for task: MemoryTask) async {
        await syncArrivalReminder(for: task)
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
        notifications.cancelArrivalReminder(taskID: task.id)
    }

    /// Place reminders ring on arrival, independent of Reminders sync
    /// (iOS Reminders has no matching cue for Orbit's places).
    private func syncArrivalReminder(for task: MemoryTask) async {
        guard let place = task.cue?.place, !task.isCompleted else {
            notifications.cancelArrivalReminder(taskID: task.id)
            return
        }
        await notifications.scheduleArrivalReminder(
            taskID: task.id,
            title: task.title,
            placeName: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            radius: place.radius,
            linkedMemoryID: task.linkedMemoryID
        )
    }

    static func fireDate(for due: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: due)
        let isDayOnly = parts.hour == TaskReminder.impliedNoonHour && parts.minute == 0 && parts.second == 0
        guard isDayOnly else { return due }
        return calendar.date(bySettingHour: TaskReminder.dayOnlyHour, minute: 0, second: 0, of: due) ?? due
    }
}

extension AppEnvironment {
    /// Longest task title taken from a memory's text.
    private static let taskTitleLimit = 80

    /// Turns a memory into a task linked back to it (Timeline's "Make
    /// Task"), titled from the memory's first line.
    func makeTask(from memory: Memory) async {
        let source = memory.content.editableText.isEmpty ? (memory.ai.summary ?? "") : memory.content.editableText
        let firstLine = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? source
        let title = String(firstLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.taskTitleLimit))
        let task = MemoryTask(
            title: title.isEmpty ? "Follow up" : title,
            linkedMemoryID: memory.id,
            createdAt: clock.now()
        )
        do {
            try await tasks.save(task)
            await remindersSync.mirror(task)
            await calendarSync.mirror(task)
            memoriesDidChange()
        } catch {
            OrbitLog.persistence.error("Make task failed: \(String(describing: error), privacy: .public)")
        }
    }
}
