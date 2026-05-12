import Foundation
import ActivityKit

/// Wraps the ActivityKit start / end calls for the capture Live Activity so
/// `CaptureViewModel` doesn't need to know the framework directly.
///
/// `@MainActor` because `Activity<T>` is non-Sendable and is meant to be
/// driven from the main actor — moving it across isolation boundaries
/// triggers Swift 6 data-race warnings.
@MainActor
public final class CaptureLiveActivityController {
    private var activity: Activity<CaptureActivityAttributes>?

    public init() {}

    /// Begins the capture Live Activity. Silently no-ops when the user has
    /// disabled Live Activities in iOS Settings — premium feel is more
    /// important than complaining about something the user controls.
    public func start(at date: Date = .init()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Defensive: tear down any stray activity before requesting a fresh
        // one. The teardown runs fire-and-forget — the system handles the
        // dismissal animation, we don't need to wait for it before starting
        // again.
        endActiveFireAndForget()

        // Spell the generic out: the bare `.init(startedAt:)` form lets Swift
        // pick the `Encodable`-constrained `ActivityContent` initializer,
        // which fails because the inferred type is `Encodable`.
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
    public func end() {
        endActiveFireAndForget()
    }

    /// Detach the activity from `self` and let it dismiss in the background.
    /// We null the stored handle *before* spawning the task so a re-entrant
    /// `start` can't see a stale activity, and we hand the handle off via an
    /// `@unchecked Sendable` box because `Activity<T>` itself is not
    /// Sendable in the public ActivityKit interface.
    private func endActiveFireAndForget() {
        guard let current = activity else { return }
        self.activity = nil
        let handle = ActivityHandle(current)
        Task.detached {
            await handle.value.end(nil, dismissalPolicy: .immediate)
        }
    }

    private struct ActivityHandle: @unchecked Sendable {
        let value: Activity<CaptureActivityAttributes>
        init(_ value: Activity<CaptureActivityAttributes>) { self.value = value }
    }
}
