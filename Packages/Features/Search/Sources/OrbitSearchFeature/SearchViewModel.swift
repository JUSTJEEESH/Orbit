import Foundation
import Observation
import OrbitDomain
import OrbitKit

@MainActor
@Observable
public final class SearchViewModel {
    public enum Scope: String, CaseIterable, Hashable, Sendable {
        case all, note, voice, photo, link

        public var title: String {
            switch self {
            case .all:   return "All"
            case .note:  return "Notes"
            case .voice: return "Voice"
            case .photo: return "Photos"
            case .link:  return "Links"
            }
        }

        var kinds: Set<MemoryContentKind> {
            switch self {
            case .all:   return []
            case .note:  return [.text]
            case .voice: return [.voiceNote]
            case .photo: return [.image, .screenshot]
            case .link:  return [.link]
            }
        }
    }

    public enum LoadState: Equatable {
        case idle
        case searching
        case results
        case empty
        case failed(String)
    }

    public var query: String = ""
    public var scope: Scope = .all
    public private(set) var results: [SearchMemoriesUseCase.Result] = []
    public private(set) var state: LoadState = .idle

    private let searchMemories: SearchMemoriesUseCase
    private let removeMemory: @MainActor @Sendable (UUID) async throws -> Void
    private var pendingSearch: Task<Void, Never>?

    public init(
        searchMemories: SearchMemoriesUseCase,
        removeMemory: @escaping @MainActor @Sendable (UUID) async throws -> Void
    ) {
        self.searchMemories = searchMemories
        self.removeMemory = removeMemory
    }

    /// Debounced search. Cancels the previous in-flight query each time the
    /// user types so we never render stale results.
    public func queryDidChange() {
        pendingSearch?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            state = .idle
            return
        }
        let snapshotScope = scope
        pendingSearch = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
            await self?.runSearch(text: trimmed, scope: snapshotScope)
        }
    }

    public func scopeDidChange() {
        queryDidChange()
    }

    private func runSearch(text: String, scope: Scope) async {
        state = .searching
        let request = SearchQuery(text: text, kinds: scope.kinds, limit: 50)
        do {
            let hits = try await searchMemories(request)
            results = hits
            state = hits.isEmpty ? .empty : .results
        } catch {
            OrbitLog.search.error("Search failed: \(String(describing: error), privacy: .public)")
            state = .failed("Search couldn't run right now. Try again in a moment.")
        }
    }

    /// Optimistically drops the result row, then calls the injected
    /// remove use case. On failure restores the snapshot — the row
    /// snaps back into place rather than leaving the user with a stale
    /// "deleted" UI while the memory is still on disk.
    public func delete(id: UUID) {
        let snapshot = results
        let snapshotState = state
        results.removeAll { $0.memory.id == id }
        if results.isEmpty && state == .results {
            state = .empty
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.removeMemory(id)
            } catch {
                self.results = snapshot
                self.state = snapshotState
            }
        }
    }
}
