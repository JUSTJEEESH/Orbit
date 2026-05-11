import Foundation
import Speech

/// Wraps `SFSpeechRecognizer` for on-device transcription of a recorded
/// audio file. We force on-device recognition so transcripts never leave the
/// device — a core Orbit privacy promise.
public actor SpeechTranscriber {
    public enum Failure: Error, Sendable {
        case permissionDenied
        case recognizerUnavailable
        case onDeviceUnavailable
        case recognitionFailed(String)
    }

    private let locale: Locale

    public init(locale: Locale = Locale.current) {
        self.locale = locale
    }

    public func transcribe(fileAt url: URL) async throws -> String {
        let permission = await ensurePermission()
        guard permission == .granted else { throw Failure.permissionDenied }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw Failure.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw Failure.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: Failure.recognitionFailed(error.localizedDescription))
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString)
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
