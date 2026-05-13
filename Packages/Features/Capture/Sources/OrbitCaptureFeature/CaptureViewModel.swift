import Foundation
import Observation
import UIKit
import OrbitDomain
import OrbitMedia
import OrbitKit
import OrbitDesignSystem
import OrbitStore

@MainActor
@Observable
public final class CaptureViewModel {

    // MARK: - Mode

    public var mode: CaptureTypeSwitcher.Kind = .text

    // MARK: - Text mode

    public var textDraft: String = "" {
        didSet { scheduleDraftSave() }
    }

    // MARK: - Voice mode

    public enum VoiceState: Sendable {
        case idle
        case recording(elapsed: TimeInterval, levels: [Float])
        case transcribing(file: StoredFile, duration: TimeInterval, levels: [Float])
        case recorded(file: StoredFile, duration: TimeInterval, transcript: String?)
    }
    public var voiceState: VoiceState = .idle

    // MARK: - Photo mode

    public var photoData: Data?
    public var photoCaption: String = ""

    // MARK: - Link mode

    public var linkText: String = ""
    public var linkPreview: LinkPreviewFetcher.Preview?
    public var linkPreviewLoading: Bool = false

    // MARK: - Shared

    public var isSaving: Bool = false
    public var errorMessage: String?
    /// True when `errorMessage` was set because the user denied a system
    /// permission Orbit needs (mic or speech). The view uses this to
    /// surface an "Open Settings" button alongside the message.
    public var errorOffersSettings: Bool = false
    /// Set when a ProGate trips during capture (currently only
    /// `.voiceLength`). The view watches this to surface the soft
    /// paywall inline. The audio captured up to the cap is preserved
    /// in `voiceState` so the user can still save what they recorded.
    public var lockedGate: ProGate?
    /// Future surface date for Time Capsule. `nil` means surface
    /// immediately. UI exposes this through a "Schedule for later" toggle.
    public var surfaceDate: Date?
    /// When true, the saved memory is flagged as a Letter to Future Me.
    /// The LetterCaptureView entry point sets this; standard captures
    /// don't.
    public var isLetter: Bool = false

    // MARK: - Dependencies

    private let captureMemory: CaptureMemoryUseCase
    private let mediaStorage: MediaStorage
    private let speechTranscriber: SpeechTranscriber
    private let linkFetcher: LinkPreviewFetcher
    private let drafts: DraftStore
    private let liveActivity = CaptureLiveActivityController()
    /// Closure that returns the current maximum recording length for
    /// voice notes, or `nil` for unlimited (Pro). Evaluated on every
    /// recorder tick so a Pro upgrade mid-recording lifts the cap
    /// immediately.
    private let voiceCapProvider: @MainActor () -> TimeInterval?

    private var recorder: VoiceRecorder?
    private var recordTask: Task<Void, Never>?
    private var draftSaveTask: Task<Void, Never>?

    public init(
        captureMemory: CaptureMemoryUseCase,
        mediaStorage: MediaStorage,
        speechTranscriber: SpeechTranscriber,
        linkFetcher: LinkPreviewFetcher,
        drafts: DraftStore = .userDefaults,
        voiceCapProvider: @escaping @MainActor () -> TimeInterval? = { nil }
    ) {
        self.captureMemory = captureMemory
        self.mediaStorage = mediaStorage
        self.speechTranscriber = speechTranscriber
        self.linkFetcher = linkFetcher
        self.drafts = drafts
        self.voiceCapProvider = voiceCapProvider
        self.textDraft = drafts.loadTextDraft() ?? ""
    }

    /// Seconds remaining before the free-tier voice cap auto-stops the
    /// current recording. `nil` when no cap applies (Pro) or no
    /// recording is in flight. The view uses this to show a quiet
    /// "Xs left on free" hint as the user approaches the limit.
    public var voiceRemainingSeconds: TimeInterval? {
        guard let cap = voiceCapProvider() else { return nil }
        guard case .recording(let elapsed, _) = voiceState else { return nil }
        return max(0, cap - elapsed)
    }

    /// Called by the view when the user dismisses the soft paywall
    /// presented for `lockedGate`. We never clear it automatically —
    /// the user owns the dismiss action.
    public func clearLockedGate() {
        lockedGate = nil
    }

    // MARK: - Save

    public var canSave: Bool {
        guard !isSaving else { return false }
        switch mode {
        case .text:
            return !textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .voice:
            if case .recorded = voiceState { return true }
            return false
        case .photo:
            return photoData != nil
        case .link:
            return URL(string: linkText.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme != nil
        }
    }

    /// Returns the saved memory's ID on success so the caller can schedule
    /// AI enrichment, or `nil` if the save failed or there was nothing to
    /// save.
    public func save() async -> UUID? {
        guard canSave else { return nil }
        isSaving = true
        errorMessage = nil
        do {
            let memory: Memory
            switch mode {
            case .text:
                let text = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                memory = try await captureMemory(
                    content: .text(text),
                    surfaceDate: surfaceDate,
                    isLetter: isLetter
                )
                drafts.clearTextDraft()
                textDraft = ""

            case .voice:
                guard case .recorded(let file, let duration, let transcript) = voiceState else {
                    throw CaptureError.invalidState
                }
                let asset = MediaAsset(
                    kind: .audio,
                    filename: file.filename,
                    byteSize: file.byteSize,
                    createdAt: Date()
                )
                memory = try await captureMemory(
                    content: .voiceNote(transcript: transcript, duration: duration),
                    media: [asset],
                    surfaceDate: surfaceDate,
                    isLetter: isLetter
                )
                voiceState = .idle

            case .photo:
                guard let data = photoData else { throw CaptureError.invalidState }
                let stored = try await mediaStorage.write(data, kind: .image)
                let asset = MediaAsset(
                    kind: .image,
                    filename: stored.filename,
                    byteSize: stored.byteSize,
                    createdAt: Date()
                )
                let caption = photoCaption.trimmingCharacters(in: .whitespacesAndNewlines)
                memory = try await captureMemory(
                    content: .image(caption: caption.isEmpty ? nil : caption),
                    media: [asset],
                    surfaceDate: surfaceDate,
                    isLetter: isLetter
                )
                photoData = nil
                photoCaption = ""

            case .link:
                let raw = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: raw), url.scheme != nil else {
                    throw CaptureError.invalidState
                }
                memory = try await captureMemory(
                    content: .link(url: url, title: linkPreview?.title, summary: linkPreview?.summary),
                    surfaceDate: surfaceDate,
                    isLetter: isLetter
                )
                linkText = ""
                linkPreview = nil
            }
            isSaving = false
            Haptics.play(.success)
            return memory.id
        } catch {
            isSaving = false
            errorMessage = "Couldn't save. Try again."
            Haptics.play(.failure)
            return nil
        }
    }

    // MARK: - Voice recording

    public func startRecording() async {
        // Pre-flight both mic and speech permissions before we open the
        // audio session. Catching denials up-front means the user can't
        // talk into a recording that will never transcribe — they get
        // a clear "open Settings" path instead.
        guard await ensureVoicePermissions() else { return }

        let recorder = VoiceRecorder(storage: mediaStorage)
        self.recorder = recorder
        do {
            let stream = try await recorder.start()
            voiceState = .recording(elapsed: 0, levels: [])
            // Surface the recording in the Dynamic Island + Lock Screen.
            // Silently no-ops if Live Activities are off in iOS Settings.
            liveActivity.start()
            recordTask = Task { @MainActor [weak self] in
                guard let self else { return }
                var collected: [Float] = []
                var autoStopOnCap = false
                for await event in stream {
                    collected.append(event.level)
                    if collected.count > 600 { collected.removeFirst(collected.count - 600) }
                    self.voiceState = .recording(elapsed: event.elapsed, levels: collected)

                    // Free-tier cap. Evaluating the closure every tick
                    // lets a Pro upgrade mid-recording lift the cap
                    // immediately — we never freeze the value at start.
                    if let cap = self.voiceCapProvider(), event.elapsed >= cap {
                        autoStopOnCap = true
                        break
                    }
                }
                if autoStopOnCap {
                    // Side-effects happen outside the stream loop so
                    // recorder.stop() can finalize cleanly. lockedGate
                    // is set after the stop returns, when voiceState
                    // is already on .recorded — that way the soft
                    // paywall surfaces over a card showing the audio
                    // the user just captured, not over a half-torn-
                    // down recording state.
                    await self.stopRecording()
                    self.lockedGate = .voiceLength
                }
            }
            Haptics.play(.impactRigid)
        } catch {
            OrbitLog.capture.error("Voice record start failed: \(String(describing: error), privacy: .public)")
            self.recorder = nil
            errorMessage = "Couldn't start recording. Try again in a moment."
            voiceState = .idle
            Haptics.play(.failure)
        }
    }

    public func stopRecording() async {
        guard let recorder else { return }
        recordTask?.cancel()
        recordTask = nil
        // End the activity as soon as the user stops capturing, regardless
        // of what comes next (transcription, silent-clip cleanup, error).
        liveActivity.end()
        do {
            let result = try await recorder.stop()
            self.recorder = nil

            // If the recorder never registered any signal (Mac / sim
            // mic broken, mic muted, app denied at the device level
            // after grant), tell the user clearly instead of saving
            // an empty voice memo with "No transcript".
            if result.wasSilent {
                try? await mediaStorage.delete(filename: result.file.filename)
                voiceState = .idle
                errorMessage = "We didn't hear anything. Check your microphone, then try again."
                Haptics.play(.failure)
                return
            }

            voiceState = .transcribing(file: result.file, duration: result.duration, levels: result.peakLevels)
            do {
                let transcript = try await speechTranscriber.transcribe(fileAt: result.file.url)
                voiceState = .recorded(file: result.file, duration: result.duration, transcript: transcript)
                Haptics.play(.success)
            } catch {
                // Audio is preserved on disk — the user can save the
                // memory without a transcript and retry later, or hit
                // Retry now while the capture sheet is still open.
                voiceState = .recorded(file: result.file, duration: result.duration, transcript: nil)
                errorMessage = "Couldn't transcribe. Your recording is saved — tap Retry to try again."
                errorOffersSettings = false
                Haptics.play(.warning)
            }
        } catch {
            OrbitLog.capture.error("Voice record stop failed: \(String(describing: error), privacy: .public)")
            self.recorder = nil
            errorMessage = "Couldn't save your recording. Try again."
            voiceState = .idle
            Haptics.play(.failure)
        }
    }

    public func discardRecording() async {
        if case .recorded(let file, _, _) = voiceState {
            try? await mediaStorage.delete(filename: file.filename)
        }
        // Ensure the activity is gone if the user discards mid-recording too.
        liveActivity.end()
        voiceState = .idle
    }

    /// Re-runs transcription against the already-recorded audio file.
    /// Used by the in-session Retry button when the first attempt fails.
    /// The audio is never re-captured — only the transcription pass is
    /// repeated, so the user doesn't lose what they said.
    public func retryTranscription() async {
        guard case .recorded(let file, let duration, _) = voiceState else { return }
        errorMessage = nil
        errorOffersSettings = false
        voiceState = .transcribing(file: file, duration: duration, levels: [])
        do {
            let transcript = try await speechTranscriber.transcribe(fileAt: file.url)
            voiceState = .recorded(file: file, duration: duration, transcript: transcript)
            Haptics.play(.success)
        } catch {
            voiceState = .recorded(file: file, duration: duration, transcript: nil)
            errorMessage = "Still couldn't transcribe. Your recording is saved — try again in a moment."
            Haptics.play(.warning)
        }
    }

    /// Opens iOS Settings so the user can grant mic / speech access when
    /// they've previously denied it. Called from the error banner.
    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Returns true when both mic and speech recognition are granted and
    /// recording can proceed. On a denial, sets a user-facing
    /// `errorMessage` + flips `errorOffersSettings` so the view can
    /// surface an Open Settings affordance.
    private func ensureVoicePermissions() async -> Bool {
        // Microphone.
        if AudioPermission.current == .undetermined {
            _ = await AudioPermission.request()
        }
        if AudioPermission.current != .granted {
            errorMessage = "Microphone access is off. Turn it on in Settings to record voice notes."
            errorOffersSettings = true
            Haptics.play(.warning)
            return false
        }

        // Speech recognition.
        if SpeechPermission.current == .undetermined {
            _ = await SpeechPermission.request()
        }
        if SpeechPermission.current != .granted {
            errorMessage = "Speech recognition is off. Turn it on in Settings so Orbit can transcribe voice notes."
            errorOffersSettings = true
            Haptics.play(.warning)
            return false
        }

        errorMessage = nil
        errorOffersSettings = false
        return true
    }

    // MARK: - Link preview

    public func fetchLinkPreview() async {
        let raw = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), url.scheme != nil else { return }
        linkPreviewLoading = true
        do {
            linkPreview = try await linkFetcher.fetch(url)
        } catch {
            linkPreview = nil
        }
        linkPreviewLoading = false
    }

    // MARK: - Draft persistence

    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        let snapshot = textDraft
        draftSaveTask = Task { [drafts] in
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            drafts.saveTextDraft(snapshot)
        }
    }

    public enum CaptureError: Error { case invalidState }
}
