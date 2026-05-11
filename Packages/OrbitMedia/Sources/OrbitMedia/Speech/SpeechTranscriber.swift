import Foundation
import OSLog
import Speech

private let log = Logger(subsystem: "com.orbit.app", category: "speech")

/// Wraps `SFSpeechRecognizer` for transcription of a recorded audio file.
///
/// Strategy: try on-device recognition first (Orbit's privacy default).
/// If the on-device path errors out — most commonly because the locale's
/// offline model isn't installed (`kAFAssistantErrorDomain` code 1101) —
/// fall back to default recognition, which routes the audio through
/// Apple's transcription server. The audio file itself is local; only
/// the on-the-wire transcription request leaves the device, and Apple's
/// policy is to not retain it.
///
/// If both paths fail, the caller treats the voice memo as "saved
/// without transcript" — the audio is still preserved on disk.
public actor SpeechTranscriber {
    public enum Failure: Error, Sendable {
        case permissionDenied
        case recognizerUnavailable
        case recognitionFailed(String)
    }

    private let locale: Locale

    public init(locale: Locale = Locale.current) {
        self.locale = locale
    }

    public func transcribe(fileAt url: URL) async throws -> String {
        let permission = await ensurePermission()
        guard permission == .granted else { throw Failure.permissionDenied }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        log.notice("Transcribing \(url.lastPathComponent, privacy: .public) (\(fileSize) bytes)")

        // Refuse early if the recorder produced an empty file — every
        // SFSpeechRecognizer error path downstream gets confusing if we
        // hand it nothing.
        guard fileSize > 1024 else {
            log.error("Audio file too small (\(fileSize) bytes) — skipping transcription")
            throw Failure.recognitionFailed("Recording was empty.")
        }

        do {
            return try await runRecognition(url: url, requireOnDevice: true)
        } catch {
            log.notice("On-device path failed (\(String(describing: error), privacy: .public)) — falling back to default")
            return try await runRecognition(url: url, requireOnDevice: false)
        }
    }

    private func runRecognition(url: URL, requireOnDevice: Bool) async throws -> String {
        let locale = self.locale
        // Race the recognition against a hard timeout — Apple's framework
        // sometimes never invokes the callback when the audio export
        // stage fails internally, and we'd hang the capture flow forever.
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await Self.runRecognitionInternal(
                    url: url,
                    locale: locale,
                    requireOnDevice: requireOnDevice
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(20))
                throw Failure.recognitionFailed("Transcription timed out.")
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw Failure.recognitionFailed("No result.")
            }
            return result
        }
    }

    /// Static so it captures only Sendable parameters (URL, Locale, Bool).
    /// The non-Sendable `SFSpeechRecognizer` + request are built inside
    /// the task — they never cross an isolation boundary.
    private static func runRecognitionInternal(
        url: URL,
        locale: Locale,
        requireOnDevice: Bool
    ) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw Failure.recognizerUnavailable
        }
        if requireOnDevice && !recognizer.supportsOnDeviceRecognition {
            throw Failure.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requireOnDevice

        // `SFSpeechRecognizer` can call its callback multiple times for
        // a single request (partial errors, retries). `withChecked*` traps
        // on double-resume — we serialize through a tiny guard so only
        // the first terminal callback wins.
        let resumeGuard = ResumeGuard()

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if resumeGuard.consume() {
                        continuation.resume(
                            throwing: Failure.recognitionFailed(error.localizedDescription)
                        )
                    }
                    return
                }
                if let result, result.isFinal {
                    if resumeGuard.consume() {
                        continuation.resume(
                            returning: result.bestTranscription.formattedString
                        )
                    }
                }
            }
        }
    }

    private func ensurePermission() async -> SpeechPermission.Status {
        let current = SpeechPermission.current
        if current == .undetermined {
            return await SpeechPermission.request()
        }
        return current
    }
}

/// Lock-protected one-shot flag. `SFSpeechRecognizer`'s callback can fire
/// more than once for a single recognition request; we use this to make
/// sure only the first terminal event resumes the continuation.
private final class ResumeGuard: @unchecked Sendable {
    private var consumed = false
    private let lock = NSLock()

    func consume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !consumed else { return false }
        consumed = true
        return true
    }
}
