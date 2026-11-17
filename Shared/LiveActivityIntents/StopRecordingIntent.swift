import AppIntents
import Foundation

/// The Stop button on Orbit's recording Live Activity (Lock Screen and
/// Dynamic Island). Compiled into both the app and the widget extension;
/// as a `LiveActivityIntent` it runs in the app's process, where the
/// recording lives, and asks the active recorder to stop and save.
struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription("Stops Orbit's voice recording and keeps what you said.")

    func perform() async throws -> some IntentResult {
        // Same name as `Notification.Name.orbitStopRecordingRequested` in
        // OrbitKit. Spelled out here because the widget extension, which
        // also compiles this file, doesn't link OrbitKit.
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("com.joshgreen.orbit.stopRecordingRequested"), object: nil)
        }
        return .result()
    }
}
