import Foundation
import AVFoundation
import Observation

/// Wraps `AVAudioRecorder` for the watch app. Mirrors the iPhone's voice
/// recorder format (16-bit LPCM mono, 16 kHz) so the file format is
/// identical on both sides — the iPhone's transcriber doesn't need to know
/// which device produced the recording.
@MainActor
@Observable
final class WatchRecorder {
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var isRecording: Bool = false

    private var recorder: AVAudioRecorder?
    private var tickTask: Task<Void, Never>?
    private var startedAt: Date?
    private var fileURL: URL?

    enum RecorderError: LocalizedError {
        case failedToStart
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .failedToStart:    return "Couldn't start recording."
            case .permissionDenied: return "Microphone access denied."
            }
        }
    }

    /// Begins recording into a fresh temp file. Returns the file URL so the
    /// caller can keep it around without poking inside the recorder.
    func start() async throws -> URL {
        let granted = await requestPermission()
        guard granted else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else { throw RecorderError.failedToStart }

        self.recorder = recorder
        self.fileURL = url
        self.startedAt = Date()
        self.isRecording = true
        self.elapsed = 0

        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRecording, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        return url
    }

    /// Stops recording. Returns the resulting file URL + duration, or nil if
    /// there was nothing to stop.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, let url = fileURL, let startedAt else { return nil }
        recorder.stop()
        let duration = Date().timeIntervalSince(startedAt)
        tickTask?.cancel(); tickTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        self.recorder = nil
        self.fileURL = nil
        self.startedAt = nil
        self.isRecording = false
        return (url, duration)
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
