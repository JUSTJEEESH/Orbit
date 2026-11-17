import CoreLocation
import Foundation
import UserNotifications
import UIKit
import Observation
import os

/// Owns the user's local-notification preferences and scheduling. Today the
/// only notification is the Daily Recap nudge; the surface stays narrow on
/// purpose — premium apps respect the lock screen.
///
/// Lifecycle:
/// 1. `init` loads persisted preferences and installs the
///    `UNUserNotificationCenter` delegate so foreground banners and tap
///    routing both work.
/// 2. The app calls `bootstrap()` once on launch to refresh authorization
///    state and reschedule the pending request after a cold start.
/// 3. Settings drives `setEnabled` / `setTime`, which persist + reschedule.
/// 4. When the user taps a delivered recap notification, `onOpenRecap` is
///    invoked on the main actor — wired by `AppEnvironment` to present the
///    daily-recap modal.
@MainActor
@Observable
public final class NotificationService {
    public nonisolated static let recapNotificationID = "com.orbit.dailyRecap"
    public nonisolated static let sealedDeliveryPrefix = "com.orbit.sealed."
    public nonisolated static let resurfacingPrefix = "com.orbit.resurface."
    public nonisolated static let taskReminderPrefix = "com.orbit.task."
    public nonisolated static let arrivalReminderPrefix = "com.orbit.arrive."
    public nonisolated static let personReminderPrefix = "com.orbit.person."
    public nonisolated static let briefingPrefix = "com.orbit.briefing."
    private static let resurfacingEnabledKey = "orbit.notifications.resurfacing.enabled"

    private static let enabledKey = "orbit.notifications.dailyRecap.enabled"
    private static let hourKey = "orbit.notifications.dailyRecap.hour"
    private static let minuteKey = "orbit.notifications.dailyRecap.minute"
    private static let defaultHour = 20
    private static let defaultMinute = 0

    /// Per-memory notification identifier for sealed delivery. Stable so
    /// scheduling can be re-applied / cancelled deterministically.
    public nonisolated static func sealedDeliveryIdentifier(for memoryID: UUID) -> String {
        sealedDeliveryPrefix + memoryID.uuidString
    }

    public private(set) var isEnabled: Bool
    public private(set) var time: DateComponents
    public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Invoked on the main actor when the user taps the recap notification.
    /// `AppEnvironment` wires this to flip `requestedModal` to `.dailyRecap`.
    public var onOpenRecap: (@MainActor () -> Void)?
    /// Invoked when the user taps a notification about one memory (a
    /// resurfaced memory or an arriving letter / time capsule).
    public var onOpenMemory: (@MainActor (UUID) -> Void)?
    /// Invoked when the user taps a before-you-meet briefing notification,
    /// with the briefing's ID.
    public var onOpenBriefing: (@MainActor (String) -> Void)?

    /// Whether the daily "Worth remembering" notification is on.
    public private(set) var isResurfacingEnabled: Bool

    private let center = UNUserNotificationCenter.current()
    private let delegate: Delegate

    public init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.isResurfacingEnabled = defaults.bool(forKey: Self.resurfacingEnabledKey)
        let hour = defaults.object(forKey: Self.hourKey) as? Int ?? Self.defaultHour
        let minute = defaults.object(forKey: Self.minuteKey) as? Int ?? Self.defaultMinute
        self.time = DateComponents(hour: hour, minute: minute)
        self.delegate = Delegate()

        delegate.openRecap = { [weak self] in
            Task { @MainActor in self?.onOpenRecap?() }
        }
        delegate.openMemory = { [weak self] id in
            Task { @MainActor in self?.onOpenMemory?(id) }
        }
        delegate.openBriefing = { [weak self] id in
            Task { @MainActor in self?.onOpenBriefing?(id) }
        }
        center.delegate = delegate
    }

    /// Refreshes the live authorization status and reinstates the schedule
    /// after a cold start. Safe to call on every launch.
    public func bootstrap() async {
        await refreshAuthorizationStatus()
        if isEnabled, isAuthorized {
            await reschedule()
        }
    }

    /// Pulls the latest authorization state from the system. The user can
    /// revoke at any time from iOS Settings, so we never cache the answer.
    public func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            OrbitLog.app.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Toggle the daily recap on/off. When enabling for the first time, the
    /// user is prompted for permission; if they decline, the toggle silently
    /// snaps back to off so the UI mirrors the real state.
    public func setEnabled(_ enabled: Bool) async {
        if enabled {
            if authorizationStatus == .notDetermined {
                _ = await requestAuthorization()
            } else {
                await refreshAuthorizationStatus()
            }
            guard isAuthorized else {
                isEnabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                return
            }
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            await reschedule()
        } else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            cancel()
        }
    }

    /// Updates the scheduled time. Only hour + minute are stored; the calendar
    /// trigger repeats daily.
    public func setTime(hour: Int, minute: Int) async {
        let bounded = DateComponents(
            hour: max(0, min(23, hour)),
            minute: max(0, min(59, minute))
        )
        self.time = bounded
        UserDefaults.standard.set(bounded.hour, forKey: Self.hourKey)
        UserDefaults.standard.set(bounded.minute, forKey: Self.minuteKey)
        if isEnabled, isAuthorized {
            await reschedule()
        }
    }

    /// Opens the iOS Settings app on Orbit's page so the user can flip
    /// notifications back on after a previous denial.
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Sealed delivery (Time Capsule + Letter)

    /// Schedules a one-shot local notification at `surfaceDate` for a sealed
    /// memory. Identifier is deterministic so re-scheduling replaces any
    /// existing request, and `cancelSealedDelivery` can find it by UUID
    /// when the user deletes the memory.
    ///
    /// Best-effort: silent no-op when permission isn't granted, when the
    /// surface date has already passed, or when the user disabled Daily
    /// Recap (we piggyback on the same Notifications permission — there
    /// is no separate toggle for sealed delivery in v1 because users
    /// usually want both or neither).
    public func scheduleSealedDelivery(
        memoryID: UUID,
        surfaceDate: Date,
        isLetter: Bool,
        previewText: String?
    ) async {
        await refreshAuthorizationStatus()
        guard isAuthorized else { return }
        guard surfaceDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = isLetter ? "A letter just arrived" : "A memory resurfaced"
        if let previewText, !previewText.isEmpty {
            content.body = String(previewText.prefix(140))
        } else {
            content.body = isLetter
                ? "Your past self left this for you to read today."
                : "Something you tucked away is back."
        }
        content.sound = .default
        content.userInfo = [
            "kind": isLetter ? "sealedLetter" : "sealedCapsule",
            "memoryID": memoryID.uuidString
        ]

        // Calendar trigger fires once at the exact moment, surviving reboot.
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: surfaceDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let identifier = Self.sealedDeliveryIdentifier(for: memoryID)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            OrbitLog.app.error("Failed to schedule sealed delivery: \(String(describing: error), privacy: .public)")
        }
    }

    /// Drops the pending notification for a sealed memory — used when the
    /// user deletes a sealed memory before it surfaces.
    public func cancelSealedDelivery(memoryID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.sealedDeliveryIdentifier(for: memoryID)]
        )
    }

    // MARK: - Task reminders

    /// Schedules (or replaces) the alert for a task due at `fireDate`.
    /// Asks for notification permission the first time.
    public func scheduleTaskReminder(taskID: UUID, title: String, fireDate: Date, linkedMemoryID: UUID?) async {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard isAuthorized, fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Reminder from Orbit"
        content.sound = .default
        var info: [String: String] = ["kind": "task", "taskID": taskID.uuidString]
        if let linkedMemoryID { info["memoryID"] = linkedMemoryID.uuidString }
        content.userInfo = info
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: Self.taskReminderPrefix + taskID.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            OrbitLog.app.error("Failed to schedule task reminder: \(String(describing: error), privacy: .public)")
        }
    }

    public func cancelTaskReminder(taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.taskReminderPrefix + taskID.uuidString])
    }

    // MARK: - Arrival reminders

    /// Schedules (or replaces) an alert delivered by iOS when the user
    /// arrives within `radius` meters of a place. iOS watches the region,
    /// so it works with Orbit closed and needs only "While Using" location
    /// access.
    public func scheduleArrivalReminder(
        taskID: UUID,
        title: String,
        placeName: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        linkedMemoryID: UUID?
    ) async {
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard isAuthorized else { return }
        let identifier = Self.arrivalReminderPrefix + taskID.uuidString
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "You\u{2019}re at \(placeName)"
        content.sound = .default
        var info: [String: String] = ["kind": "arrival", "taskID": taskID.uuidString]
        if let linkedMemoryID { info["memoryID"] = linkedMemoryID.uuidString }
        content.userInfo = info
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNLocationNotificationTrigger(region: region, repeats: false)
        )
        do {
            try await center.add(request)
        } catch {
            OrbitLog.app.error("Failed to schedule arrival reminder: \(String(describing: error), privacy: .public)")
        }
    }

    public func cancelArrivalReminder(taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.arrivalReminderPrefix + taskID.uuidString])
    }

    // MARK: - Person reminders

    /// One "you're seeing Alex" alert, timed to a calendar event.
    public struct PersonReminderItem: Sendable {
        public let taskID: UUID
        public let title: String
        public let body: String
        public let fireDate: Date
        public let linkedMemoryID: UUID?

        public init(taskID: UUID, title: String, body: String, fireDate: Date, linkedMemoryID: UUID?) {
            self.taskID = taskID
            self.title = title
            self.body = body
            self.fireDate = fireDate
            self.linkedMemoryID = linkedMemoryID
        }
    }

    /// Replaces every pending person reminder with `items`, so moved,
    /// cancelled or completed ones never ring stale.
    public func replacePersonReminders(_ items: [PersonReminderItem]) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(Self.personReminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        guard !items.isEmpty else { return }
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard isAuthorized else { return }
        for item in items where item.fireDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            var info: [String: String] = ["kind": "person", "taskID": item.taskID.uuidString]
            if let linkedMemoryID = item.linkedMemoryID { info["memoryID"] = linkedMemoryID.uuidString }
            content.userInfo = info
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let request = UNNotificationRequest(
                identifier: Self.personReminderPrefix + item.taskID.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                OrbitLog.app.error("Failed to schedule person reminder: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Before-you-meet briefings

    /// One briefing notification: "Lunch with Alex in 30 minutes".
    public struct BriefingItem: Sendable {
        public let briefingID: String
        public let title: String
        public let body: String
        public let fireDate: Date

        public init(briefingID: String, title: String, body: String, fireDate: Date) {
            self.briefingID = briefingID
            self.title = title
            self.body = body
            self.fireDate = fireDate
        }
    }

    /// Replaces every pending briefing notification. Briefings never ask
    /// for notification permission themselves: they only ring if the user
    /// already allowed Orbit's notifications.
    public func replaceBriefings(_ items: [BriefingItem]) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(Self.briefingPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        guard !items.isEmpty else { return }
        await refreshAuthorizationStatus()
        guard isAuthorized else { return }
        for item in items where item.fireDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            // Silent: a heads-up before a meeting, not an alarm.
            content.sound = nil
            content.userInfo = ["kind": "briefing", "briefingID": item.briefingID]
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let request = UNNotificationRequest(
                identifier: Self.briefingPrefix + item.briefingID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                OrbitLog.app.error("Failed to schedule briefing: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Resurfacing ("Worth remembering")

    /// One scheduled resurfacing notification.
    public struct ResurfacingItem: Sendable {
        public let memoryID: UUID
        public let preview: String
        public let fireDate: Date

        public init(memoryID: UUID, preview: String, fireDate: Date) {
            self.memoryID = memoryID
            self.preview = preview
            self.fireDate = fireDate
        }
    }

    /// Turns the daily resurfacing notification on or off. Turning it on
    /// asks for notification permission if needed.
    /// - Returns: whether it's on afterwards.
    @discardableResult
    public func setResurfacingEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            await refreshAuthorizationStatus()
            if !isAuthorized {
                guard await requestAuthorization() else { return false }
            }
        } else {
            await cancelResurfacing()
        }
        isResurfacingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.resurfacingEnabledKey)
        return enabled
    }

    /// Replaces the pending resurfacing notifications with `items`. Content
    /// is fixed when scheduled, so the app re-plans the next few days on
    /// every launch.
    public func scheduleResurfacing(_ items: [ResurfacingItem]) async {
        await cancelResurfacing()
        await refreshAuthorizationStatus()
        guard isResurfacingEnabled, isAuthorized else { return }
        for item in items where item.fireDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Worth remembering"
            content.body = String(item.preview.prefix(140))
            content.sound = nil
            content.interruptionLevel = .passive
            content.userInfo = ["kind": "resurface", "memoryID": item.memoryID.uuidString]
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let request = UNNotificationRequest(
                identifier: Self.resurfacingPrefix + item.memoryID.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            do {
                try await center.add(request)
            } catch {
                OrbitLog.app.error("Failed to schedule resurfacing: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func cancelResurfacing() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(Self.resurfacingPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private func reschedule() async {
        cancel()
        let content = UNMutableNotificationContent()
        content.title = "Daily Recap"
        content.body = "A quiet moment to revisit your day."
        content.sound = .default
        content.userInfo = ["kind": "dailyRecap"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.recapNotificationID,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            OrbitLog.app.notice("Daily recap scheduled for \(self.time.hour ?? -1):\(self.time.minute ?? -1)")
        } catch {
            OrbitLog.app.error("Failed to schedule daily recap: \(String(describing: error), privacy: .public)")
        }
    }

    private func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.recapNotificationID])
    }

    // MARK: - Delegate

    /// `UNUserNotificationCenter` calls its delegate off the main actor, so we
    /// host the conformance on a small `NSObject` and hop back to the main
    /// actor before mutating any state.
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
        var openRecap: (@Sendable () -> Void)?
        var openMemory: (@Sendable (UUID) -> Void)?
        var openBriefing: (@Sendable (String) -> Void)?

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            let request = response.notification.request
            if request.identifier == NotificationService.recapNotificationID {
                openRecap?()
            } else if let briefingID = request.content.userInfo["briefingID"] as? String {
                openBriefing?(briefingID)
            } else if let raw = request.content.userInfo["memoryID"] as? String, let id = UUID(uuidString: raw) {
                // Resurfaced memories and arriving letters / capsules open
                // the memory itself. (1.x ignored taps on these.)
                openMemory?(id)
            }
        }
    }
}
