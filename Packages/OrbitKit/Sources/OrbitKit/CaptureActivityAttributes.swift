import Foundation
import ActivityKit

/// The shared Live Activity payload for an active voice capture. Lives in
/// OrbitKit so both the main app (which starts and ends the activity) and
/// the widget extension (which renders the Dynamic Island + Lock Screen
/// surfaces) can speak the same type.
///
/// The static side is empty — every capture session looks the same to the
/// system. The dynamic state holds only what's needed to drive the live
/// timer; we deliberately don't push amplitude updates because that would
/// burn the activity-update budget for no real UX gain.
public struct CaptureActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    public struct State: Codable, Hashable, Sendable {
        /// The wall-clock moment recording began. The widget renders the
        /// elapsed time as `Text(_:style:.timer)`, which advances itself —
        /// no per-tick updates needed from the host app.
        public var startedAt: Date

        public init(startedAt: Date) {
            self.startedAt = startedAt
        }
    }

    public init() {}
}
