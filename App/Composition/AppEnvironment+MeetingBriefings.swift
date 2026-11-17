import Foundation
import OrbitDomain
import OrbitKit
import os

/// Before-you-meet briefings: 30 minutes before a calendar event with
/// someone Orbit knows about, a quiet notification and a Home card with
/// what you last talked about, open promises and things to bring up.
/// Calendar events are read on device; nothing leaves the phone.
extension AppEnvironment {
    private enum BriefingKeys {
        static let enabled = "orbit.briefings.enabled"
    }

    static var storedMeetingBriefingsPreference: Bool {
        UserDefaults.standard.object(forKey: BriefingKeys.enabled) as? Bool ?? true
    }

    /// Briefings run only when the switch is on and calendar access exists.
    var meetingBriefingsActive: Bool {
        meetingBriefingsEnabled && calendarSync.isAuthorized
    }

    /// The briefing Home shows now, if any.
    var currentMeetingBriefing: MeetingBriefing? {
        let now = clock.now()
        return meetingBriefings.first { MeetingBriefingPolicy.isCurrent($0.event, now: now) }
    }

    /// Rebuilds briefings and their notifications. Runs on launch and
    /// foreground; cheap when off.
    func refreshMeetingBriefings() async {
        calendarSync.refreshAuthorizationStatus()
        guard meetingBriefingsActive else {
            meetingBriefings = []
            await notifications.replaceBriefings([])
            return
        }
        let now = clock.now()
        // Start a little in the past so a meeting that just began still
        // has its Home card.
        let events = calendarSync.events(
            from: now.addingTimeInterval(-MeetingBriefingPolicy.startedGrace),
            to: now.addingTimeInterval(MeetingBriefingPolicy.lookahead)
        )
        do {
            meetingBriefings = try await loadMeetingBriefings(events: events)
        } catch {
            OrbitLog.app.error("Briefings: couldn't build: \(String(describing: error), privacy: .public)")
            return
        }
        await notifications.replaceBriefings(meetingBriefings.map { briefing in
            NotificationService.BriefingItem(
                briefingID: briefing.id,
                title: notificationTitle(for: briefing),
                body: briefing.summary,
                fireDate: MeetingBriefingPolicy.notificationDate(for: briefing.event)
            )
        })
    }

    /// Finds a briefing for a notification tap. A cold launch from the
    /// notification may arrive before the first refresh, so it rebuilds
    /// once if needed.
    func meetingBriefing(id: String) async -> MeetingBriefing? {
        if let found = meetingBriefings.first(where: { $0.id == id }) { return found }
        await refreshMeetingBriefings()
        return meetingBriefings.first { $0.id == id }
    }

    /// The Settings switch. Turning it on asks for calendar access only if
    /// the user hasn't decided yet.
    func setMeetingBriefingsEnabled(_ enabled: Bool) async {
        if enabled {
            guard await calendarSync.requestAccessIfUndecided() else {
                // Denied: leave the switch off so it matches reality.
                meetingBriefingsEnabled = false
                UserDefaults.standard.set(false, forKey: BriefingKeys.enabled)
                await refreshMeetingBriefings()
                return
            }
        }
        meetingBriefingsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: BriefingKeys.enabled)
        await refreshMeetingBriefings()
    }

    /// "Lunch with Alex in 30 minutes", or "Alex's birthday today".
    private func notificationTitle(for briefing: MeetingBriefing) -> String {
        let minutes = Int(MeetingBriefingPolicy.leadTime / 60)
        return briefing.event.isAllDay ? "\(briefing.title) today" : "\(briefing.title) in \(minutes) minutes"
    }
}
