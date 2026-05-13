import Foundation
import Observation
import OrbitDomain
import OrbitKit

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
    /// Optional sleep + steps for the recap date. The surface shows a
    /// quiet footer when this is non-nil; nil means "skip the row" so
    /// users without HealthKit on never see an empty placeholder.
    public private(set) var healthSnapshot: HealthSnapshot?

    private let date: Date?
    private let generate: GenerateDailyRecapUseCase
    private let memories: any MemoryRepository
    private let healthKit: HealthKitService?

    /// `date == nil` → today's recap.
    public init(
        date: Date? = nil,
        generate: GenerateDailyRecapUseCase,
        memories: any MemoryRepository,
        healthKit: HealthKitService? = nil
    ) {
        self.date = date
        self.generate = generate
        self.memories = memories
        self.healthKit = healthKit
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
            OrbitLog.app.error("Recap generation failed: \(String(describing: error), privacy: .public)")
            self.state = .failed("Couldn't generate today's recap. Try again in a moment.")
        }

        // Pull HealthKit data after the recap is on screen so primary
        // copy never waits on Health. Only attempt the read when the user
        // has already gone through the prompt.
        if let healthKit, healthKit.isEnabled {
            let snapshot = await healthKit.snapshot(for: date ?? Date())
            self.healthSnapshot = snapshot.isEmpty ? nil : snapshot
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
