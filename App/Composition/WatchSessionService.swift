import Foundation
import WatchConnectivity
import OrbitDomain
import OrbitMedia
import OrbitKit

/// iPhone-side `WCSession` host. Activates on launch, listens for files
/// transferred from the watch app, copies the audio into the shared media
/// store, persists the memory as a voice note, and kicks off transcription
/// + enrichment via the supplied callback so the watch capture flows
/// through the same downstream pipeline as on-device captures.
///
/// Queued behavior: `WCSession.transferFile` survives termination — files
/// initiated by the watch while the iPhone is asleep arrive when the user
/// next launches the app, because `activate()` flushes the queue.
@MainActor
final class WatchSessionService {
    private let mediaStorage: MediaStorage
    private let captureMemory: CaptureMemoryUseCase
    private let speechTranscriber: SpeechTranscriber
    /// Invoked on the main actor after a watch capture lands. AppEnvironment
    /// wires this to bump the memory-list version + schedule enrichment so
    /// the timeline picks up the new row and AI metadata fills in.
    var onCapture: (@MainActor (UUID) -> Void)?

    private let delegate: SessionDelegate

    init(
        mediaStorage: MediaStorage,
        captureMemory: CaptureMemoryUseCase,
        speechTranscriber: SpeechTranscriber
    ) {
        self.mediaStorage = mediaStorage
        self.captureMemory = captureMemory
        self.speechTranscriber = speechTranscriber
        self.delegate = SessionDelegate()
        // `[String: Any]?` isn't Sendable, so the delegate extracts the only
        // metadata field we actually use (duration) before crossing isolation
        // back to the @MainActor service.
        delegate.onFileReceived = { [weak self] url, duration in
            Task { @MainActor in
                await self?.ingest(fileAt: url, duration: duration)
            }
        }
    }

    func activate() {
        guard WCSession.isSupported() else {
            OrbitLog.app.info("WatchConnectivity unsupported on this device.")
            return
        }
        WCSession.default.delegate = delegate
        WCSession.default.activate()
    }

    /// Copies the incoming file into managed storage, persists a voice-note
    /// memory, then runs transcription in the background so the user sees
    /// the row land immediately. Failures are logged but never surface to
    /// the user — a watch capture happens out of band, the iPhone hasn't
    /// asked permission to interrupt.
    private func ingest(fileAt incomingURL: URL, duration: TimeInterval) async {
        do {
            let data = try Data(contentsOf: incomingURL)
            let stored = try await mediaStorage.write(data, kind: .audio)

            let asset = MediaAsset(
                kind: .audio,
                filename: stored.filename,
                byteSize: stored.byteSize,
                createdAt: Date()
            )
            let memory = try await captureMemory(
                content: .voiceNote(transcript: nil, duration: duration),
                media: [asset]
            )
            onCapture?(memory.id)
            OrbitLog.app.notice("Captured watch voice note: \(memory.id, privacy: .public)")

            // Transcription runs separately so the row lands in the timeline
            // immediately. If transcription fails we keep the audio-only
            // memory rather than discarding the user's recording.
            Task {
                do {
                    _ = try await speechTranscriber.transcribe(fileAt: stored.url)
                    // TODO: persist the transcript onto the existing memory
                    // once UpdateMemoryUseCase exposes a transcript-only
                    // path. For now, enrichment will pick up the audio.
                } catch {
                    OrbitLog.app.error("Watch capture transcription failed: \(String(describing: error), privacy: .public)")
                }
            }
        } catch {
            OrbitLog.app.error("Failed to ingest watch capture: \(String(describing: error), privacy: .public)")
        }
    }
}

/// `WCSessionDelegate` conformance — kept on a separate NSObject so the
/// service can stay on `@MainActor`.
private final class SessionDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {
    var onFileReceived: ((URL, TimeInterval) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // The iOS docs require re-activation after deactivation, which
        // happens when the user switches paired watches.
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Copy the file out of the session-owned temp location before
        // returning — the system reclaims `file.fileURL` as soon as the
        // delegate method returns.
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-incoming-\(UUID().uuidString).wav")
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: scratch)
            let duration = (file.metadata?["duration"] as? TimeInterval) ?? 0
            onFileReceived?(scratch, duration)
        } catch {
            // Nothing else to do — log and drop. The watch already
            // considers the transfer complete.
        }
    }
}
