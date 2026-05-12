import Foundation
import ActivityKit

/// Wraps the ActivityKit start / end calls for the capture Live Activity so
/// `CaptureViewModel` doesn't need to know the framework directly.
///
/// `@MainActor` because `Activity<T>` is non-Sendable and is meant to be
/// driven from the main actor — moving it across isolation boundaries
/// triggers Swift 6 data-race warnings even when nothing actually races.
@MainActor
public final class CaptureLiveActivityController {
    private var activity: Activity<CaptureActivityAttributes>?

    public init() {}

    /// Begins the capture Live Activity. Silently no-ops when the user has
    /// disabled Live Activities in iOS Settings — premium feel is more
    /// important than complaining about something the user controls.
    public func start(at date: Date = .init()) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Defensive: end any stray activity before starting a fresh one.
        await endIfActive()

        // Spell the generic out: the bare `.init(startedAt:)` form lets Swift
        // pick the `Encodable`-constrained `ActivityContent` initializer,
        // which fails because the inferred type is `Encodable`. Naming the
        // state type pins the right overload.
        let state = CaptureActivityAttributes.ContentState(startedAt: date)
        let content = ActivityContent<CaptureActivityAttributes.ContentState>(
            state: state,
            staleDate: nil
        )
        let attributes = CaptureActivityAttributes()
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
        await endIfActive()
    }

    /// Tear down the active activity in place. We null out the stored handle
    /// *before* awaiting `end` so a re-entrant `start` during the suspension
    /// can't see a stale activity and end the new one.
    private func endIfActive() async {
        guard let current = activity else { return }
        self.activity = nil
        await current.end(nil, dismissalPolicy: .immediate)
    }
}
