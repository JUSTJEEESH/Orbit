import Foundation
import Observation
import OrbitDomain
import OrbitMedia
import OrbitKit
import OrbitDesignSystem

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

    // MARK: - Dependencies

    private let captureMemory: CaptureMemoryUseCase
    private let mediaStorage: MediaStorage
    private let speechTranscriber: SpeechTranscriber
    private let linkFetcher: LinkPreviewFetcher
    private let drafts: DraftStore

    private var recorder: VoiceRecorder?
    private var recordTask: Task<Void, Never>?
    private var draftSaveTask: Task<Void, Never>?

    public init(
        captureMemory: CaptureMemoryUseCase,
        mediaStorage: MediaStorage,
        speechTranscriber: SpeechTranscriber,
        linkFetcher: LinkPreviewFetcher,
        drafts: DraftStore = .userDefaults
    ) {
        self.captureMemory = captureMemory
        self.mediaStorage = mediaStorage
        self.speechTranscriber = speechTranscriber
        self.linkFetcher = linkFetcher
        self.drafts = drafts
        self.textDraft = drafts.loadTextDraft() ?? ""
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

    /// Returns `true` on a successful save so the caller can dismiss.
    public func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        do {
            switch mode {
            case .text:
                let text = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await captureMemory(content: .text(text))
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
                _ = try await captureMemory(
                    content: .voiceNote(transcript: transcript, duration: duration),
                    media: [asset]
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
                _ = try await captureMemory(
                    content: .image(caption: caption.isEmpty ? nil : caption),
                    media: [asset]
                )
                photoData = nil
                photoCaption = ""

            case .link:
                let raw = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: raw), url.scheme != nil else {
                    throw CaptureError.invalidState
                }
                _ = try await captureMemory(
                    content: .link(url: url, title: linkPreview?.title, summary: linkPreview?.summary)
                )
                linkText = ""
                linkPreview = nil
            }
            isSaving = false
            Haptics.play(.success)
            return true
        } catch {
            isSaving = false
            errorMessage = "Couldn't save. Try again."
            Haptics.play(.failure)
            return false
        }
    }

    // MARK: - Voice recording

    public func startRecording() async {
        let recorder = VoiceRecorder(storage: mediaStorage)
        self.recorder = recorder
        do {
            let stream = try await recorder.start()
            voiceState = .recording(elapsed: 0, levels: [])
            recordTask = Task { @MainActor [weak self] in
                guard let self else { return }
                var collected: [Float] = []
                for await event in stream {
                    collected.append(event.level)
                    if collected.count > 600 { collected.removeFirst(collected.count - 600) }
                    self.voiceState = .recording(elapsed: event.elapsed, levels: collected)
                }
            }
            Haptics.play(.impactRigid)
        } catch {
            self.recorder = nil
            errorMessage = error.localizedDescription
            voiceState = .idle
            Haptics.play(.failure)
        }
    }

    public func stopRecording() async {
        guard let recorder else { return }
        recordTask?.cancel()
        recordTask = nil
        do {
            let result = try await recorder.stop()
            self.recorder = nil
            voiceState = .transcribing(file: result.file, duration: result.duration, levels: result.peakLevels)
            do {
                let transcript = try await speechTranscriber.transcribe(fileAt: result.file.url)
                voiceState = .recorded(file: result.file, duration: result.duration, transcript: transcript)
            } catch {
                voiceState = .recorded(file: result.file, duration: result.duration, transcript: nil)
            }
            Haptics.play(.success)
        } catch {
            self.recorder = nil
            errorMessage = error.localizedDescription
            voiceState = .idle
            Haptics.play(.failure)
        }
    }

    public func discardRecording() async {
        if case .recorded(let file, _, _) = voiceState {
            try? await mediaStorage.delete(filename: file.filename)
        }
        voiceState = .idle
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
