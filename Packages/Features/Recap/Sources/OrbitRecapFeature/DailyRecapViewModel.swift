import Foundation
import Observation
import OrbitDomain

@MainActor
@Observable
public final class DailyRecapViewModel {
    public enum LoadState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    public private(set) var state: LoadState = .loading
    public private(set) var recap: DailyRecap?
    public private(set) var highlights: [Memory] = []

    private let date: Date?
    private let generate: GenerateDailyRecapUseCase
    private let memories: any MemoryRepository

    /// `date == nil` → today's recap.
    public init(
        date: Date? = nil,
        generate: GenerateDailyRecapUseCase,
        memories: any MemoryRepository
    ) {
        self.date = date
        self.generate = generate
        self.memories = memories
    }

    public func load() async {
        state = .loading
        do {
            let recap = try await generate(for: date)
            guard let recap else {
                state = .empty
                return
            }
            self.recap = recap
            self.highlights = await resolveHighlights(recap.highlightIDs)
            self.state = .loaded
        } catch {
            self.state = .failed(String(describing: error))
        }
    }

    public func refresh() async {
        await load()
    }

    private func resolveHighlights(_ ids: [UUID]) async -> [Memory] {
        var result: [Memory] = []
        result.reserveCapacity(ids.count)
        for id in ids {
            if let memory = try? await memories.memory(with: id) {
                result.append(memory)
            }
        }
        return result
    }
}
