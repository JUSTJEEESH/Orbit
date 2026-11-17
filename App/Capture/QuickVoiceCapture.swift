import Foundation
import Observation
import os
import OrbitKit
import OrbitDomain
import OrbitMedia
import OrbitStore

/// Hold-to-talk: press and hold the mic in the capture bar to record, let go
/// to save. No sheet, no choices — the fastest way to get a thought out of
/// your head. The words appear while you hold, and the memory is saved
/// (audio first) the moment you let go.
@MainActor
@Observable
final class QuickVoiceCapture {
    enum State: Equatable {
        case idle
        case recording(elapsed: TimeInterval, level: Float, transcript: String)
        case saving
    }

    private(set) var state: State = .idle

    /// Recordings shorter than this are treated as an accidental press and
    /// discarded instead of saved.
    static let minimumDuration: TimeInterval = 0.8

    private let storage: MediaStorage
    private let capture: CaptureMemoryUseCase
    private let voiceCap: @MainActor () -> TimeInterval?
    /// Called with each saved memory's ID. Installed by `AppEnvironment`.
    var onSaved: (@MainActor (UUID) -> Void)?

    private var recorder: LiveVoiceRecorder?
    private var listenTask: Task<Void, Never>?
    /// The microphone takes a moment to start. A release that arrives in
    /// that window is remembered and applied once recording begins, so the
    /// mic can never be left running.
    private var isStarting = false
    private var finishRequested = false

    init(
        storage: MediaStorage,
        capture: CaptureMemoryUseCase,
        voiceCap: @escaping @MainActor () -> TimeInterval?
    ) {
        self.storage = storage
        self.capture = capture
        self.voiceCap = voiceCap
    }

    var isActive: Bool { state != .idle }

    func begin() async {
        guard state == .idle, !isStarting else { return }
        isStarting = true
        finishRequested = false
        let recorder = LiveVoiceRecorder(storage: storage)
        self.recorder = recorder
        defer { isStarting = false }
        do {
            let events = try await recorder.start()
            state = .recording(elapsed: 0, level: 0, transcript: "")
            Haptics.play(.impactRigid)
            listenTask = Task { @MainActor [weak self] in
                for await event in events {
                    guard let self, case .recording = self.state else { break }
                    self.state = .recording(elapsed: event.elapsed, level: event.level, transcript: event.transcript)
                    // Free-tier length cap: save what was said so far.
                    if let cap = self.voiceCap(), event.elapsed >= cap {
                        await self.finish()
                        break
                    }
                }
            }
            if finishRequested {
                isStarting = false
                await finish()
            }
        } catch {
            OrbitLog.capture.error("Hold-to-talk couldn't start: \(String(describing: error), privacy: .public)")
            self.recorder = nil
            state = .idle
            Haptics.play(.failure)
        }
    }

    /// Stops and saves. Too-short or silent recordings are discarded.
    func finish() async {
        if isStarting {
            finishRequested = true
            return
        }
        guard case .recording = state, let recorder else { return }
        state = .saving
        listenTask?.cancel()
        listenTask = nil
        self.recorder = nil
        do {
            let result = try await recorder.stop()
            guard result.duration >= Self.minimumDuration, !result.wasSilent else {
                try? await storage.delete(filename: result.file.filename)
                state = .idle
                return
            }
            let asset = MediaAsset(kind: .audio, filename: result.file.filename, byteSize: result.file.byteSize, createdAt: Date())
            let memory = try await capture(
                content: .voiceNote(transcript: result.transcript, duration: result.duration),
                media: [asset],
                transcriptSegments: result.segments
            )
            state = .idle
            Haptics.play(.success)
            onSaved?(memory.id)
        } catch {
            OrbitLog.capture.error("Hold-to-talk save failed: \(String(describing: error), privacy: .public)")
            state = .idle
            Haptics.play(.failure)
        }
    }
}
