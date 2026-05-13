import Foundation
import EventKit
import UIKit
import Observation
import OrbitDomain
import OrbitKit

/// Two-way mirror between Orbit tasks and iOS Calendar.
///
/// When sync is on, every due-dated `MemoryTask` becomes an `EKEvent`
/// in a dedicated "Orbit" calendar — so tasks surface on the Lock
/// Screen, the Today view, Apple Watch, and CarPlay alongside the
/// user's real meetings. Task completion / deletion update or remove
/// the mirrored event. The service also exposes `upcomingEvents(...)`
/// so other features (Tasks → "Upcoming") can fold the user's real
/// calendar into Orbit's timeline.
///
/// Mirrors `RemindersSyncService` in shape — same enable/disable
/// dance, same `lastError` surface, same UserDefaults-backed toggle.
@MainActor
@Observable
public final class CalendarSyncService {
    private static let enabledKey = "orbit.calendar.sync.enabled"
    private static let orbitCalendarTitle = "Orbit"

    public private(set) var isEnabled: Bool
    public private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    /// Human-readable description of the last sync failure, surfaced in
    /// Settings → Calendar. Silent failures (no writeable source,
    /// permission revoked, save error) used to be invisible to the
    /// user — this is the breadcrumb.
    public private(set) var lastError: String?

    private let store = EKEventStore()
    private let tasks: any TaskRepository

    public init(tasks: any TaskRepository) {
        self.tasks = tasks
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    public var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    /// Asks iOS for full calendar access. Returns true if granted.
    /// Callers should refresh the toggle UI from the resulting
    /// `isEnabled` — a denial silently flips sync back off so the
    /// user's switch matches reality.
    @discardableResult
    public func enable() async -> Bool {
        lastError = nil
        if !isAuthorized {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if !granted {
                    isEnabled = false
                    UserDefaults.standard.set(false, forKey: Self.enabledKey)
                    OrbitLog.app.notice("Calendar permission declined.")
                    return false
                }
            } catch {
                OrbitLog.app.error("Calendar auth request failed: \(String(describing: error), privacy: .public)")
                lastError = "Couldn't reach Calendar. Try again from Settings."
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

        // Provision the "Orbit" calendar if missing. Unlike Reminders
        // (where the user picks a list), we own a dedicated calendar
        // so mirrored tasks are easy to recognize and removable as a
        // group if the user changes their mind later.
        guard ensureOrbitCalendar() != nil else {
            lastError = "Couldn't create the Orbit calendar. Make sure iCloud Calendar or a local calendar is enabled."
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return false
        }
        OrbitLog.app.notice("Calendar sync ready.")

        isEnabled = true
        UserDefaults.standard.set(true, forKey: Self.enabledKey)

        // Mirror everything we already have so the user's existing
        // due-dated tasks show up the moment they flip the switch on.
        await mirrorAllTasks()
        return true
    }

    /// Flips sync off without revoking iOS-level permission or
    /// deleting existing mirrored events. The user can re-enable
    /// later and reconnect to the same events by identifier.
    public func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
    }

    public func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Mutation mirror

    /// Mirrors a single task into Calendar — creating the EKEvent on
    /// first call, then updating it on every subsequent call. Persists
    /// the new identifier back to the task repository so the link
    /// survives a relaunch. Tasks without a `dueDate` are skipped
    /// (we don't pollute Calendar with timeless captures).
    public func mirror(_ task: MemoryTask) async {
        guard isEnabled else { return }
        guard isAuthorized else {
            lastError = "Calendar access isn't granted. Re-enable in iOS Settings."
            return
        }
        guard let dueDate = task.dueDate else {
            // No due date — nothing to put on the calendar. If a prior
            // version of this task had one and was mirrored, the
            // event is now stale; remove it so the calendar stays
            // truthful to current state.
            if task.calendarEventIdentifier != nil {
                await removeMirror(for: task)
            }
            return
        }
        guard let calendar = ensureOrbitCalendar() else {
            lastError = "Couldn't access the Orbit calendar."
            return
        }

        let event: EKEvent
        if let identifier = task.calendarEventIdentifier,
           let existing = store.event(withIdentifier: identifier) {
            event = existing
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = calendar
        }

        event.title = task.isCompleted ? "✓ \(task.title)" : task.title
        event.notes = task.notes
        event.startDate = dueDate
        // 30-minute default event so it doesn't read as an all-day
        // block in calendar grids unless the due date itself was
        // marked all-day at task creation time.
        event.endDate = dueDate.addingTimeInterval(30 * 60)
        event.isAllDay = false

        do {
            try store.save(event, span: .thisEvent, commit: true)
            lastError = nil
            OrbitLog.app.notice("Mirrored task to Calendar: \(event.title ?? "(untitled)", privacy: .public).")
            if task.calendarEventIdentifier != event.eventIdentifier {
                var updated = task
                updated.calendarEventIdentifier = event.eventIdentifier
                try? await tasks.update(updated)
            }
        } catch {
            OrbitLog.app.error("Mirror to Calendar failed: \(String(describing: error), privacy: .public)")
            lastError = "Couldn't save to Calendar. Try again."
        }
    }

    /// Tears down the EKEvent behind a task — fire when the user
    /// deletes the Orbit task. Swallows lookup failures because the
    /// user might have already deleted the event manually.
    public func removeMirror(for task: MemoryTask) async {
        guard let identifier = task.calendarEventIdentifier else { return }
        guard isAuthorized else { return }
        guard let event = store.event(withIdentifier: identifier) else { return }
        do {
            try store.remove(event, span: .thisEvent, commit: true)
        } catch {
            OrbitLog.app.error("Remove Calendar mirror failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Read-back

    /// Upcoming events from the user's real calendars over the next
    /// `days` days. Excludes events in the Orbit-owned calendar so
    /// mirrored tasks don't duplicate Orbit's own UI. Returns an
    /// empty array if sync is off or permission isn't granted.
    public func upcomingEvents(within days: Int = 7) async -> [UpcomingCalendarEvent] {
        guard isAuthorized else { return [] }
        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: now) else { return [] }

        let orbitCalendar = orbitCalendarIfExists()
        // Search across every calendar except Orbit's own — Apple's
        // `predicateForEvents(withStart:end:calendars:)` takes nil to
        // mean "all calendars," which is what we want minus one.
        let allCalendars = store.calendars(for: .event).filter { $0 != orbitCalendar }
        guard !allCalendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: allCalendars)
        let events = store.events(matching: predicate)
        return events.compactMap { event -> UpcomingCalendarEvent? in
            guard let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty
            else { return nil }
            return UpcomingCalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: title,
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                calendarTitle: event.calendar?.title ?? ""
            )
        }
    }

    // MARK: - Helpers

    private func mirrorAllTasks() async {
        let all = (try? await tasks.allTasks()) ?? []
        for task in all where task.dueDate != nil {
            await mirror(task)
        }
    }

    /// Finds the "Orbit" calendar, creating it on the first writeable
    /// source if missing. Prefers iCloud, then a local source, so the
    /// user sees mirrored events across all their devices when iCloud
    /// is configured.
    private func ensureOrbitCalendar() -> EKCalendar? {
        if let existing = orbitCalendarIfExists() {
            return existing
        }
        guard let source = preferredSource() else { return nil }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.orbitCalendarTitle
        calendar.source = source
        calendar.cgColor = UIColor.systemBlue.cgColor
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            OrbitLog.app.error("Create Orbit calendar failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func orbitCalendarIfExists() -> EKCalendar? {
        store.calendars(for: .event)
            .first(where: { $0.title == Self.orbitCalendarTitle && $0.allowsContentModifications })
    }

    private func preferredSource() -> EKSource? {
        let sources = store.sources
        if let iCloud = sources.first(where: { $0.sourceType == .calDAV && $0.title.lowercased() == "icloud" }) {
            return iCloud
        }
        if let local = sources.first(where: { $0.sourceType == .local }) {
            return local
        }
        return sources.first(where: { $0.sourceType != .subscribed && $0.sourceType != .birthdays })
    }
}

/// A flattened, framework-free view of an EKEvent so feature packages
/// don't need to import EventKit just to render the user's calendar
/// alongside Orbit content. Mirrors the `Sendable` value-type pattern
/// used by `HealthSnapshot`.
public struct UpcomingCalendarEvent: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String?
    public let calendarTitle: String

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        location: String?,
        calendarTitle: String
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
