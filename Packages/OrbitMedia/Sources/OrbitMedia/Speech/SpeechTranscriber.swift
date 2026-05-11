import Foundation
import Speech

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

        do {
            return try await runRecognition(url: url, requireOnDevice: true)
        } catch {
            // On-device failed (most often: model not installed). Retry
            // with the network-backed path so the user still gets a
            // transcript instead of a silent failure.
            return try await runRecognition(url: url, requireOnDevice: false)
        }
    }

    private func runRecognition(url: URL, requireOnDevice: Bool) async throws -> String {
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
