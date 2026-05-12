import Foundation
import ActivityKit

/// Wraps the ActivityKit start / end calls for the capture Live Activity so
/// `CaptureViewModel` doesn't need to know the framework directly.
///
/// One activity at a time — a capture session is implicitly singleton, so we
/// hold onto the handle and end it before requesting a new one. This makes
/// repeated start/stop cycles safe.
public actor CaptureLiveActivityController {
    private var activity: Activity<CaptureActivityAttributes>?

    public init() {}

    /// Begins the capture Live Activity. Silently no-ops when the user has
    /// disabled Live Activities in iOS Settings — premium feel is more
    /// important than complaining about something the user controls.
    public func start(at date: Date = .init()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Defensive: end any stray activity before starting a fresh one.
        if let existing = activity {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            activity = nil
        }

        let attributes = CaptureActivityAttributes()
        let content = ActivityContent(
            state: .init(startedAt: date),
            staleDate: nil
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            OrbitLog.app.error("Couldn't start capture Live Activity: \(String(describing: error), privacy: .public)")
        }
    }

    /// Ends the activity immediately, removing it from the Lock Screen +
    /// Dynamic Island. Safe to call when nothing is active.
    public func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
