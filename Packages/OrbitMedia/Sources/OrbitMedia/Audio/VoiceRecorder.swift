import AVFoundation
import Foundation

/// Records a voice note to disk and streams normalized amplitude levels plus
/// elapsed time so the UI can draw a live waveform.
///
/// Built on `AVAudioRecorder` rather than `AVAudioEngine` — we don't need
/// per-buffer access for Phase 2, and the higher-level API keeps the actor
/// boundary clean (no captured non-Sendable buffer types).
public actor VoiceRecorder {
    public struct Event: Sendable, Equatable {
        public let level: Float
        public let elapsed: TimeInterval
    }

    public enum Failure: Error, Sendable {
        case permissionDenied
        case audioEngineFailed
        case noActiveRecording
    }

    public struct Result: Sendable {
        public let file: StoredFile
        public let duration: TimeInterval
        public let peakLevels: [Float]
    }

    private let storage: MediaStorage
    private let session: AVAudioSession
    private var recorder: AVAudioRecorder?
    private var stagedFile: StoredFile?
    private var startedAt: Date?
    private var capturedLevels: [Float] = []
    private var continuation: AsyncStream<Event>.Continuation?
    private var meterTask: Task<Void, Never>?

    public init(storage: MediaStorage, session: AVAudioSession = .sharedInstance()) {
        self.storage = storage
        self.session = session
    }

    public func start() async throws -> AsyncStream<Event> {
        if AudioPermission.current != .granted {
            let granted = await AudioPermission.request()
            guard granted == .granted else { throw Failure.permissionDenied }
        }

        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])

        let file = await storage.reserveURL(kind: .audio)
        // 16 kHz mono LPCM — the format SFSpeechRecognizer ingests most
        // reliably, especially on the simulator where AAC/.m4a containers
        // sometimes export with corrupt headers.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: file.url, settings: settings)
        } catch {
            throw Failure.audioEngineFailed
        }
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw Failure.audioEngineFailed }

        self.recorder = recorder
        self.stagedFile = file
        self.startedAt = Date()
        self.capturedLevels = []

        let (stream, continuation) = AsyncStream<Event>.makeStream()
        self.continuation = continuation

        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        return stream
    }

    public func stop() async throws -> Result {
        guard let recorder, let stagedFile, let startedAt else {
            throw Failure.noActiveRecording
        }
        meterTask?.cancel()
        meterTask = nil
        recorder.stop()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])

        let duration = Date().timeIntervalSince(startedAt)
        let final = try await storage.finalize(stagedFile)
        let levels = capturedLevels

        self.recorder = nil
        self.stagedFile = nil
        self.startedAt = nil
        self.capturedLevels = []
        continuation?.finish()
        continuation = nil

        return Result(file: final, duration: duration, peakLevels: levels)
    }

    private func poll() {
        guard let recorder, let startedAt else { return }
        recorder.updateMeters()
        let dB = recorder.averagePower(forChannel: 0)
        // -60 dB silence floor → 0; 0 dB peak → 1. Smooth curve avoids the
        // waveform staying flat for normal speech levels.
        let normalized = max(0, min(1, (Double(dB) + 60) / 60))
        let elapsed = Date().timeIntervalSince(startedAt)
        let level = Float(normalized * normalized) // perceptual compression
        capturedLevels.append(level)
        continuation?.yield(Event(level: level, elapsed: elapsed))
    }
}
