import Foundation
import Observation
import UIKit
import OrbitDomain
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

    private let memoryID: UUID
    private let repository: any MemoryRepository
    private let mediaStorage: MediaStorage
    private let removeMemory: @MainActor @Sendable (UUID) async throws -> Void

    public init(
        memoryID: UUID,
        repository: any MemoryRepository,
        mediaStorage: MediaStorage,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void
    ) {
        self.memoryID = memoryID
        self.repository = repository
        self.mediaStorage = mediaStorage
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
        } catch {
            self.state = .failed(String(describing: error))
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

    // MARK: - Media

    /// Loads the first image/screenshot attachment off-main, then assigns
    /// the resulting `UIImage` on the MainActor so SwiftUI re-renders. We
    /// only decode the first matching asset; multi-attachment memories
    /// arrive in a later phase.
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
