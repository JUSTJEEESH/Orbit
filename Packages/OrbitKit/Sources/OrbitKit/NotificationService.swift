import Foundation
import UserNotifications
import UIKit
import Observation

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

    private let center = UNUserNotificationCenter.current()
    private let delegate: Delegate

    public init() {
        let defaults = UserDefaults.standard
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        let hour = defaults.object(forKey: Self.hourKey) as? Int ?? Self.defaultHour
        let minute = defaults.object(forKey: Self.minuteKey) as? Int ?? Self.defaultMinute
        self.time = DateComponents(hour: hour, minute: minute)
        self.delegate = Delegate()

        delegate.openRecap = { [weak self] in
            Task { @MainActor in self?.onOpenRecap?() }
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
            guard response.notification.request.identifier == NotificationService.recapNotificationID else { return }
            openRecap?()
        }
    }
}
