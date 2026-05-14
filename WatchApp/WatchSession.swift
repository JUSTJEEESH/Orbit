import Foundation
import WatchConnectivity
import Observation
import os

/// `WCSession` wrapper for the watch side. Activates on init, exposes the
/// transfer state via `@Observable`, and clears back to idle automatically
/// a moment after a successful send so the UI flows back to the record
/// affordance without the user having to dismiss.
@MainActor
@Observable
final class WatchSession {
    static let shared = WatchSession()

    enum State: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    var state: State = .idle

    private let delegate: SessionDelegate
    private static let log = Logger(subsystem: "com.joshgreen.orbit.watch", category: "session")

    private init() {
        self.delegate = SessionDelegate()
        delegate.onFinish = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.state = .failed(error.localizedDescription)
                } else {
                    self.state = .sent
                    try? await Task.sleep(for: .seconds(1.6))
                    if case .sent = self.state {
                        self.state = .idle
                    }
                }
            }
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = delegate
            WCSession.default.activate()
            Self.log.notice("Watch: activate() called.")
        } else {
            Self.log.error("Watch: WCSession not supported on this device.")
        }
    }

    /// Transfers a recorded file to the paired iPhone. Returns immediately —
    /// the system handles retry + queueing if the phone is unreachable.
    func send(fileAt url: URL, duration: TimeInterval) {
        guard WCSession.isSupported() else {
            state = .failed("Connectivity isn't supported on this device.")
            Self.log.error("Watch: send aborted — WCSession unsupported.")
            return
        }
        let session = WCSession.default
        Self.log.notice("Watch: send invoked. activationState=\(session.activationState.rawValue, privacy: .public) isReachable=\(session.isReachable, privacy: .public) isCompanionAppInstalled=\(session.isCompanionAppInstalled, privacy: .public)")
        guard session.activationState == .activated else {
            state = .failed("Watch isn't paired.")
            Self.log.error("Watch: send aborted — session not activated (state=\(session.activationState.rawValue, privacy: .public)).")
            return
        }
        state = .sending
        let transfer = session.transferFile(url, metadata: [
            "kind": "voiceNote",
            "duration": duration
        ])
        Self.log.notice("Watch: transferFile queued. url=\(url.lastPathComponent, privacy: .public) duration=\(duration, privacy: .public) transferring=\(transfer.isTransferring, privacy: .public)")
    }

    func reset() { state = .idle }
}

/// The `WCSessionDelegate` conformance lives on a small NSObject so the
/// outer service can stay on `@MainActor` without inheriting Objective-C
/// thread requirements.
private final class SessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    var onFinish: ((Error?) -> Void)?
    private static let log = Logger(subsystem: "com.joshgreen.orbit.watch", category: "session-delegate")

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            Self.log.error("Watch: activation completed with error: \(String(describing: error), privacy: .public)")
        } else {
            Self.log.notice("Watch: activation completed. state=\(activationState.rawValue, privacy: .public) isReachable=\(session.isReachable, privacy: .public) isCompanionAppInstalled=\(session.isCompanionAppInstalled, privacy: .public)")
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        // The watchOS docs guarantee one callback per transfer; safe to
        // clean up the local temp copy here regardless of success.
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if let error {
            Self.log.error("Watch: transfer finished with error: \(String(describing: error), privacy: .public)")
        } else {
            Self.log.notice("Watch: transfer finished successfully.")
        }
        onFinish?(error)
    }
}
