import Foundation
import Observation
import UIKit
import OrbitDomain
import OrbitKit
import OrbitMedia

@MainActor
@Observable
public final class MemoryDetailViewModel {
    public enum LoadState: Equatable {
        case loading
        case loaded
        case missing
        case failed(String)
    }

    public private(set) var state: LoadState = .loading
    public private(set) var memory: Memory?
    public private(set) var image: UIImage?
    public private(set) var voiceFileURL: URL?
    /// True while a re-transcription pass is in flight. The view uses
    /// this to disable the Retry button and show an inline progress
    /// indicator so a stalled network doesn't look like nothing's
    /// happening.
    public private(set) var isRetranscribing: Bool = false
    public private(set) var retranscribeError: String?

    private let memoryID: UUID
    private let repository: any MemoryRepository
    private let mediaStorage: MediaStorage
    private let speechTranscriber: SpeechTranscriber?
    private let removeMemory: @MainActor @Sendable (UUID) async throws -> Void

    public init(
        memoryID: UUID,
        repository: any MemoryRepository,
        mediaStorage: MediaStorage,
        speechTranscriber: SpeechTranscriber? = nil,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void
    ) {
        self.memoryID = memoryID
        self.repository = repository
        self.mediaStorage = mediaStorage
        self.speechTranscriber = speechTranscriber
        self.removeMemory = removeMemory
    }

    public func load() async {
        state = .loading
        do {
            guard let memory = try await repository.memory(with: memoryID) else {
                state = .missing
                return
            }
            self.memory = memory
            self.state = .loaded
            await loadAttachedImageIfNeeded(for: memory)
            await loadAttachedAudioIfNeeded(for: memory)
        } catch {
            OrbitLog.persistence.error("Memory load failed: \(String(describing: error), privacy: .public)")
            self.state = .failed("Couldn't load this memory. It may have been deleted.")
        }
    }

    /// Returns `true` if the memory was actually deleted, so the view can
    /// pop itself. The closure injected by the composition root handles
    /// Spotlight de-indexing + list-version bumping centrally.
    public func delete() async -> Bool {
        do {
            try await removeMemory(memoryID)
            return true
        } catch {
            return false
        }
    }

    /// Re-runs transcription against the saved voice memo's audio file
    /// and writes the new transcript back into the memory record. This
    /// is the recovery path for voice notes that were saved with a nil
    /// transcript (Speech framework hiccup, no offline model installed,
    /// transient network failure routing through Apple's servers).
    /// Returns true on a successful update so the caller can play a
    /// haptic.
    @discardableResult
    public func retranscribe() async -> Bool {
        guard !isRetranscribing else { return false }
        guard let speechTranscriber, let memory else { return false }
        guard case .voiceNote(_, let duration) = memory.content else { return false }
        guard let url = voiceFileURL else {
            retranscribeError = "The audio file is missing for this memory."
            return false
        }

        isRetranscribing = true
        retranscribeError = nil
        defer { isRetranscribing = false }

        do {
            let transcript = try await speechTranscriber.transcribe(fileAt: url)
            var updated = memory
            updated.content = .voiceNote(transcript: transcript, duration: duration)
            updated.updatedAt = Date()
            try await repository.update(updated)
            self.memory = updated
            return true
        } catch {
            retranscribeError = "Couldn't transcribe — try again in a moment."
            return false
        }
    }

    // MARK: - Media

    /// Loads the first image/screenshot attachment off-main, then assigns
    /// the resulting `UIImage` on the MainActor so SwiftUI re-renders. We
    /// only decode the first matching asset; multi-attachment memories
    /// arrive in a later phase.
    /// Resolves the on-disk URL for the memory's audio attachment, if any.
    /// Lets `MemoryDetailView` render a play/pause button without needing
    /// MediaStorage access of its own.
    private func loadAttachedAudioIfNeeded(for memory: Memory) async {
        guard case .voiceNote = memory.content,
              let asset = memory.media.first(where: { $0.kind == .audio })
        else {
            self.voiceFileURL = nil
            return
        }
        self.voiceFileURL = await mediaStorage.url(forFilename: asset.filename)
    }

    private func loadAttachedImageIfNeeded(for memory: Memory) async {
        let kindNeeded: Bool
        switch memory.content {
        case .image, .screenshot: kindNeeded = true
        default: kindNeeded = false
        }
        guard kindNeeded else { return }

        guard let asset = memory.media.first(where: { $0.kind == .image }) else { return }
        let url = await mediaStorage.url(forFilename: asset.filename)

        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value

        self.image = decoded
    }
}
