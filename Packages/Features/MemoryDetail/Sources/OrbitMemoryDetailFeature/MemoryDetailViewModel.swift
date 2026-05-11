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
    private let deleteMemory: DeleteMemoryUseCase

    public init(
        memoryID: UUID,
        repository: any MemoryRepository,
        deleteMemory: DeleteMemoryUseCase
    ) {
        self.memoryID = memoryID
        self.repository = repository
        self.deleteMemory = deleteMemory
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
    /// pop itself.
    public func delete() async -> Bool {
        do {
            try await deleteMemory(id: memoryID)
            return true
        } catch {
            return false
        }
    }
}
