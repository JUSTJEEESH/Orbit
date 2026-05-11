import Foundation
import Observation
import OrbitDomain

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

    private let memoryID: UUID
    private let repository: any MemoryRepository
    private let removeMemory: @MainActor @Sendable (UUID) async throws -> Void

    public init(
        memoryID: UUID,
        repository: any MemoryRepository,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void
    ) {
        self.memoryID = memoryID
        self.repository = repository
        self.removeMemory = removeMemory
    }

    public func load() async {
        state = .loading
        do {
            if let memory = try await repository.memory(with: memoryID) {
                self.memory = memory
                self.state = .loaded
            } else {
                self.state = .missing
            }
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
}
