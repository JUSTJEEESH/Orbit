import AVFoundation
import Foundation
import os
import OrbitDomain
import Speech

private let log = Logger(subsystem: "com.joshgreen.orbit", category: "voice.live")

/// Records a voice note while transcribing it live, on device, with Apple's
/// `SpeechAnalyzer` (iOS 26).
///
/// One microphone stream feeds two consumers:
/// 1. **The audio file, first and always.** Every buffer is written to disk
///    before anything else happens, so a transcription problem can never
///    cost the user their recording (the top complaint about rival voice
///    apps).
/// 2. **The speech analyzer**, which streams back words as they're spoken,
///    with their timings — so the transcript appears while you talk, and
///    search can later jump to the moment something was said.
///
/// If live transcription isn't available (unsupported language, model not
/// downloaded yet) it records only, starts the model download for next
/// time, and `Result.transcript` is nil so the caller can fall back to
/// transcribing the finished file.
public actor LiveVoiceRecorder {
    public struct Event: Sendable, Equatable {
        public let level: Float
        public let elapsed: TimeInterval
        /// Everything heard so far (finalized words plus the current guess).
        public let transcript: String
    }

    public struct Result: Sendable {
        public let file: StoredFile
        public let duration: TimeInterval
        public let peakLevels: [Float]
        /// Nil when live transcription wasn't running.
        public let transcript: String?
        public let segments: [TranscriptSegment]

        /// True when no real signal was heard (muted or broken microphone).
        public var wasSilent: Bool {
            (peakLevels.max() ?? 0) < Self.silenceThreshold
        }

        static let silenceThreshold: Float = 0.02
    }

    public enum Failure: Error, Sendable {
        case permissionDenied
        case audioEngineFailed
        case noActiveRecording
    }

    /// The format recordings are stored in: 16 kHz mono 16-bit PCM, the same
    /// as Orbit's earlier recorder, so every existing playback and fallback
    /// transcription path keeps working unchanged.
    private static let fileSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// Microphone buffer size: about 85 ms at 48 kHz, so the waveform and
    /// live text update roughly 12 times a second.
    private static let tapBufferSize: AVAudioFrameCount = 4_096

    private let storage: MediaStorage
    private let locale: Locale
    private let session: AVAudioSession

    private var engine: AVAudioEngine?
    private var pipeline: AudioPipeline?
    private var stagedFile: StoredFile?
    private var startedAt: Date?
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?

    public init(storage: MediaStorage, locale: Locale = .current, session: AVAudioSession = .sharedInstance()) {
        self.storage = storage
        self.locale = locale
        self.session = session
    }

    public func start() async throws -> AsyncStream<Event> {
        if AudioPermission.current != .granted {
            guard await AudioPermission.request() == .granted else { throw Failure.permissionDenied }
        }

        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let file = await storage.reserveURL(kind: .audio)

        guard let fileFormat = AVAudioFormat(settings: Self.fileSettings),
              let fileConverter = AVAudioConverter(from: inputFormat, to: fileFormat)
        else { throw Failure.audioEngineFailed }
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(
                forWriting: file.url,
                settings: Self.fileSettings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            throw Failure.audioEngineFailed
        }

        let (events, continuation) = AsyncStream<Event>.makeStream()
        let startedAt = Date()
        let pipeline = AudioPipeline(
            audioFile: audioFile,
            fileFormat: fileFormat,
            fileConverter: fileConverter,
            events: continuation,
            startedAt: startedAt
        )

        // Live transcription is optional: recording starts either way.
        await attachAnalyzer(to: pipeline, inputFormat: inputFormat)

        input.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: inputFormat) { buffer, _ in
            pipeline.process(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            pipeline.finishAnalyzerInput()
            throw Failure.audioEngineFailed
        }

        self.engine = engine
        self.pipeline = pipeline
        self.stagedFile = file
        self.startedAt = startedAt
        return events
    }

    public func stop() async throws -> Result {
        guard let engine, let pipeline, let stagedFile, let startedAt else {
            throw Failure.noActiveRecording
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        let duration = Date().timeIntervalSince(startedAt)

        // Let the analyzer finish the words still in flight.
        pipeline.finishAnalyzerInput()
        if let analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                log.error("Analyzer finalize failed: \(String(describing: error), privacy: .public)")
            }
        }
        await resultsTask?.value

        pipeline.closeFile()
        let final = try await storage.finalize(stagedFile)
        let transcript = pipeline.isTranscribing ? pipeline.finalTranscript : nil

        self.engine = nil
        self.pipeline = nil
        self.stagedFile = nil
        self.startedAt = nil
        self.analyzer = nil
        self.resultsTask = nil
        pipeline.finishEvents()

        return Result(
            file: final,
            duration: duration,
            peakLevels: pipeline.levels,
            transcript: transcript.flatMap { $0.isEmpty ? nil : $0 },
            segments: pipeline.segments
        )
    }

    // MARK: - Live transcription

    private func attachAnalyzer(to pipeline: AudioPipeline, inputFormat: AVAudioFormat) async {
        guard Speech.SpeechTranscriber.isAvailable,
              let supported = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: locale)
        else { return }

        let transcriber = Speech.SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        // Never make the user wait for a download before recording: if the
        // on-device model isn't installed yet, record only this time and
        // fetch it in the background for the next recording.
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            Task.detached(priority: .utility) {
                do {
                    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                        try await request.downloadAndInstall()
                    }
                } catch {
                    log.notice("Speech model download didn't complete: \(String(describing: error), privacy: .public)")
                }
            }
            return
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]),
              let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        else { return }

        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            log.error("Analyzer start failed: \(String(describing: error), privacy: .public)")
            return
        }
        pipeline.attachAnalyzer(input: inputBuilder, format: analyzerFormat, converter: converter)
        self.analyzer = analyzer

        resultsTask = Task.detached(priority: .userInitiated) {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        var timed: [TranscriptSegment] = []
                        for run in result.text.runs {
                            guard let range = run.audioTimeRange else { continue }
                            let words = String(result.text[run.range].characters)
                            timed.append(TranscriptSegment(text: words, start: range.start.seconds, end: range.end.seconds))
                        }
                        pipeline.appendFinal(text, segments: timed)
                    } else {
                        pipeline.setVolatile(text)
                    }
                }
            } catch {
                log.error("Live transcription stopped: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

/// Everything the real-time audio thread touches, behind a lock. The tap
/// callback runs off any actor, so this class is the one place that state is
/// shared across threads — hence `@unchecked Sendable` with a lock guarding
/// every mutable property.
private final class AudioPipeline: @unchecked Sendable {
    private let lock = NSLock()

    private var audioFile: AVAudioFile?
    private let fileFormat: AVAudioFormat
    private let fileConverter: AVAudioConverter
    private let events: AsyncStream<LiveVoiceRecorder.Event>.Continuation
    private let startedAt: Date

    private var analyzerInput: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    private var analyzerConverter: AVAudioConverter?

    private var finalized = ""
    private var volatile = ""
    private var timedSegments: [TranscriptSegment] = []
    private var capturedLevels: [Float] = []

    init(
        audioFile: AVAudioFile,
        fileFormat: AVAudioFormat,
        fileConverter: AVAudioConverter,
        events: AsyncStream<LiveVoiceRecorder.Event>.Continuation,
        startedAt: Date
    ) {
        self.audioFile = audioFile
        self.fileFormat = fileFormat
        self.fileConverter = fileConverter
        self.events = events
        self.startedAt = startedAt
    }

    var isTranscribing: Bool { lock.withLock { analyzerConverter != nil } }
    var finalTranscript: String { lock.withLock { (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines) } }
    var segments: [TranscriptSegment] { lock.withLock { Self.merge(timedSegments) } }
    var levels: [Float] { lock.withLock { capturedLevels } }

    func attachAnalyzer(input: AsyncStream<AnalyzerInput>.Continuation, format: AVAudioFormat, converter: AVAudioConverter) {
        lock.withLock {
            analyzerInput = input
            analyzerFormat = format
            analyzerConverter = converter
        }
    }

    /// Called on the audio thread for every microphone buffer.
    func process(_ buffer: AVAudioPCMBuffer) {
        let level = Self.level(of: buffer)
        lock.lock()
        // 1. Disk first.
        if let audioFile, let converted = Self.convert(buffer, using: fileConverter, to: fileFormat) {
            try? audioFile.write(from: converted)
        }
        // 2. Then the analyzer, if live transcription is running.
        if let analyzerInput, let analyzerConverter, let analyzerFormat,
           let converted = Self.convert(buffer, using: analyzerConverter, to: analyzerFormat) {
            analyzerInput.yield(AnalyzerInput(buffer: converted))
        }
        capturedLevels.append(level)
        let transcript = finalized + volatile
        lock.unlock()

        events.yield(LiveVoiceRecorder.Event(
            level: level,
            elapsed: Date().timeIntervalSince(startedAt),
            transcript: transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    func appendFinal(_ text: String, segments: [TranscriptSegment]) {
        lock.withLock {
            finalized += text
            volatile = ""
            timedSegments += segments
        }
    }

    func setVolatile(_ text: String) {
        lock.withLock { volatile = text }
    }

    func finishAnalyzerInput() {
        lock.withLock {
            analyzerInput?.finish()
            analyzerInput = nil
        }
    }

    func closeFile() {
        // Releasing the AVAudioFile flushes and closes it.
        lock.withLock { audioFile = nil }
    }

    func finishEvents() {
        events.finish()
    }

    // MARK: - Helpers

    /// Normalized loudness in [0, 1] from the buffer's RMS, with the same
    /// -60 dB floor and perceptual curve as Orbit's earlier recorder.
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        let decibels = 20 * log10(max(rms, 1e-7))
        let normalized = max(0, min(1, (decibels + 60) / 60))
        return normalized * normalized
    }

    /// Converts one buffer (sample rate and/or sample format) in a single pass.
    private static func convert(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, output.frameLength > 0 else { return nil }
        return output
    }

    /// Word-level timings are merged into phrase-sized segments (about three
    /// seconds each): plenty precise for "jump to the moment", and far
    /// smaller to store.
    private static let segmentSpan: TimeInterval = 3

    static func merge(_ words: [TranscriptSegment]) -> [TranscriptSegment] {
        var merged: [TranscriptSegment] = []
        for word in words {
            if var last = merged.last, word.start - last.start < segmentSpan {
                last.text += word.text
                last.end = word.end
                merged[merged.count - 1] = last
            } else {
                merged.append(word)
            }
        }
        return merged.map { TranscriptSegment(text: $0.text.trimmingCharacters(in: .whitespaces), start: $0.start, end: $0.end) }
    }
}
