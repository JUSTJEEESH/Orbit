import SwiftUI
import LockedCameraCapture

/// Lock Screen + Action Button + Control Center camera entry point.
///
/// Apple grants this extension a fresh per-session directory at
/// `LockedCameraCaptureSession.sessionContentURL`. We write captured photos
/// there (plus a small JSON envelope describing each one) and rely on the
/// host app's `CaptureInboxService` to drain the directory on next foreground
/// via `LockedCameraCaptureManager`. The user never has to unlock to capture
/// — this is the "thought just hit me" surface.
@main
struct OrbitCameraCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            CameraCaptureView(session: session)
        }
    }
}
