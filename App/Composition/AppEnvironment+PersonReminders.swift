import Foundation
import OrbitDomain
import OrbitKit
import os

/// "Next time I'm with Alex, ask about the trip" rings when a calendar
/// event that includes Alex starts. iPhone doesn't let apps see who you're
/// with, so Orbit reads your calendar (title and invitees) on device and
/// schedules ordinary local notifications; nothing leaves the phone.
extension AppEnvironment {
    /// Re-plans every person reminder from the next week of events. Cheap
    /// enough to run on launch, on foreground, and after task changes.
    func refreshPersonReminders() async {
        let open: [MemoryTask]
        do {
            open = try await tasks.openTasks().filter { $0.cue?.personName != nil }
        } catch {
            OrbitLog.app.error("Person reminders: couldn't read tasks: \(String(describing: error), privacy: .public)")
            return
        }
        guard !open.isEmpty else {
            await notifications.replacePersonReminders([])
            return
        }
        // First person reminder: ask for calendar access in context.
        guard await calendarSync.requestAccessIfUndecided() else {
            await notifications.replacePersonReminders([])
            return
        }
        let now = clock.now()
        let events = calendarSync.events(from: now, to: now.addingTimeInterval(PersonReminderPlanner.lookahead))
        let plans = PersonReminderPlanner.plan(tasks: open, events: events, now: now)
        await notifications.replacePersonReminders(plans.map { plan in
            NotificationService.PersonReminderItem(
                taskID: plan.taskID,
                title: plan.eventTitle.isEmpty ? "With \(plan.person)" : plan.eventTitle,
                body: plan.taskTitle,
                fireDate: plan.fireDate,
                linkedMemoryID: plan.linkedMemoryID
            )
        })
    }
}
