import Foundation

public extension Notification.Name {
    /// Posted when the user taps Stop on the recording Live Activity
    /// (`StopRecordingIntent`). The active recorder stops and saves.
    static let orbitStopRecordingRequested = Notification.Name("com.joshgreen.orbit.stopRecordingRequested")
}
