import Foundation
@preconcurrency import LockedCameraCapture
import OrbitDomain
import OrbitMedia
import OrbitKit

/// Drains capture payloads that arrived while the host app was off-screen.
///
/// Two ingest channels feed the same pipeline:
///
///   • **Lock-Screen camera** (`OrbitCameraCaptureExtension`) writes a JPEG
///     plus a sibling `.json` envelope into a per-session URL Apple owns.
///     We discover those URLs through
///     `LockedCameraCaptureManager.sessionContentUpdates`.
///   • **Safari Web Extension** (`SafariWebExtensionHandler`) writes a
///     `.json` envelope into the App Group's `Orbit/Inbox/` folder.
///
/// Once read, each envelope flows through `CaptureMemoryUseCase` the same
/// way an in-app capture would, then is deleted along with any sibling
/// media. The host kicks `drain()` on launch and again on every
/// `scenePhase == .active` so users see their clips/photos arrive within
/// one second of returning to Orbit.
@MainActor
final class CaptureInboxService {
    private let appGroupIdentifier: String
    private let mediaStorage: MediaStorage
    private let captureMemory: CaptureMemoryUseCase
    private let clock: any OrbitClock

    /// Called for every memory the service successfully creates. The
    /// composition root wires this to bump `memoryListVersion` and schedule
    /// enrichment + Spotlight indexing — same downstream as a watch capture.
    var onCapture: (@MainActor (UUID) -> Void)?

    private var lockCameraObserver: Task<Void, Never>?

    init(
        appGroupIdentifier: String,
        mediaStorage: MediaStorage,
        captureMemory: CaptureMemoryUseCase,
        clock: any OrbitClock
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.mediaStorage = mediaStorage
        self.captureMemory = captureMemory
        self.clock = clock
    }

    /// Begins observing `LockedCameraCaptureManager` for new session
    /// content. The sequence emits pre-existing session URLs on its first
    /// iteration, so a single observer covers both cold-start drains and
    /// live arrivals while the app is foregrounded. Safe to call
    /// repeatedly — re-entry replaces the observer.
    func start() {
        lockCameraObserver?.cancel()
        lockCameraObserver = Task { [weak self] in
            await self?.observeLockCameraUpdates()
        }
    }

    /// One-shot drain of the Safari inbox. The lock-camera channel runs
    /// continuously via `start()` so it doesn't need a poke here.
    func drain() async {
        await drainSafariInbox()
    }

    // MARK: - Lock-Screen camera

    private func observeLockCameraUpdates() async {
        // The framework emits a `SessionContentUpdate.added(URL)` for each
        // session that has fresh content — both ones already on disk at
        // launch and ones that arrive while the app is foregrounded.
        // Other enum cases (removals, etc.) are the system's own
        // bookkeeping; ignore them.
        let manager = LockedCameraCaptureManager.shared
        for await update in manager.sessionContentUpdates {
            if case .added(let url) = update {
                await ingestLockCameraSession(at: url)
            }
        }
    }

    private func ingestLockCameraSession(at sessionURL: URL) async {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: sessionURL, includingPropertiesForKeys: nil) else {
            return
        }
        let envelopes = entries.filter { $0.pathExtension.lowercased() == "json" }
        for envelopeURL in envelopes {
            await ingestPhotoEnvelope(at: envelopeURL, sessionDirectory: sessionURL)
        }

        // Tell the system we're done — frees the per-session sandbox.
        do {
            try await LockedCameraCaptureManager.shared.invalidateSessionContent(at: sessionURL)
        } catch {
            OrbitLog.app.error("Failed to invalidate locked-camera session: \(String(describing: error), privacy: .public)")
        }
    }

    private func ingestPhotoEnvelope(at envelopeURL: URL, sessionDirectory: URL) async {
        guard let data = try? Data(contentsOf: envelopeURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        guard (json["kind"] as? String) == "photo",
              let imageFilename = json["imageFilename"] as? String
        else { return }

        let imageURL = sessionDirectory.appendingPathComponent(imageFilename)
        guard let imageData = try? Data(contentsOf: imageURL) else { return }

        do {
            let stored = try await mediaStorage.write(imageData, kind: .image)
            let asset = MediaAsset(
                kind: .image,
                filename: stored.filename,
                byteSize: stored.byteSize,
                createdAt: clock.now()
            )
            let memory = try await captureMemory(
                content: .image(caption: nil),
                media: [asset]
            )
            onCapture?(memory.id)
            OrbitLog.app.notice("Ingested lock-camera photo: \(memory.id, privacy: .public)")
        } catch {
            OrbitLog.app.error("Lock-camera ingest failed: \(String(describing: error), privacy: .public)")
        }

        // Files live in Apple's per-session sandbox, but tidy up anyway so
        // an `invalidate` failure doesn't leave duplicates on next launch.
        try? FileManager.default.removeItem(at: envelopeURL)
        try? FileManager.default.removeItem(at: imageURL)
    }

    // MARK: - Safari inbox

    private func drainSafariInbox() async {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else { return }
        let inbox = container
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("Inbox", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: nil
        ) else { return }

        for envelopeURL in entries where envelopeURL.pathExtension.lowercased() == "json" {
            await ingestSafariEnvelope(at: envelopeURL)
        }
    }

    private func ingestSafariEnvelope(at envelopeURL: URL) async {
        guard let data = try? Data(contentsOf: envelopeURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            try? FileManager.default.removeItem(at: envelopeURL)
            return
        }

        let kind = (json["kind"] as? String) ?? "text"
        let content: MemoryContent? = {
            switch kind {
            case "link":
                guard let urlString = json["url"] as? String,
                      let url = URL(string: urlString) else { return nil }
                let title = json["title"] as? String
                let selection = json["selection"] as? String
                return .link(url: url, title: title, summary: selection)
            case "text":
                guard let selection = json["selection"] as? String, !selection.isEmpty else { return nil }
                return .text(selection)
            default:
                return nil
            }
        }()

        guard let content else {
            try? FileManager.default.removeItem(at: envelopeURL)
            return
        }

        do {
            let memory = try await captureMemory(content: content)
            onCapture?(memory.id)
            OrbitLog.app.notice("Ingested Safari clip: \(memory.id, privacy: .public)")
        } catch {
            OrbitLog.app.error("Safari clip ingest failed: \(String(describing: error), privacy: .public)")
        }

        try? FileManager.default.removeItem(at: envelopeURL)
    }
}
