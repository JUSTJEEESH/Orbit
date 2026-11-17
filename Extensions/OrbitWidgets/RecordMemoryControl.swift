import AppIntents
import SwiftUI
import WidgetKit

/// Deep links the controls and widgets open.
enum OrbitCaptureLinks {
    /// Opens capture already recording a voice note.
    static let record = URL(string: "orbit://record") ?? URL(fileURLWithPath: "/")
    /// Opens the text capture sheet.
    static let write = URL(string: "orbit://capture") ?? URL(fileURLWithPath: "/")
}

/// "Record a Memory" — a Control for Control Center, the Lock Screen and the
/// Action Button. One press opens Orbit already recording, so a thought is
/// caught before it's gone.
struct RecordMemoryControl: ControlWidget {
    static let kind = "com.joshgreen.orbit.controls.record"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(OrbitCaptureLinks.record)) {
                Label("Record a Memory", systemImage: "mic.fill")
            }
        }
        .displayName("Record a Memory")
        .description("Opens Orbit already recording a voice note.")
    }
}

/// "Write a Memory" — the same, opening the text capture sheet.
struct WriteMemoryControl: ControlWidget {
    static let kind = "com.joshgreen.orbit.controls.write"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(OrbitCaptureLinks.write)) {
                Label("Write a Memory", systemImage: "square.and.pencil")
            }
        }
        .displayName("Write a Memory")
        .description("Opens Orbit to capture a thought.")
    }
}
