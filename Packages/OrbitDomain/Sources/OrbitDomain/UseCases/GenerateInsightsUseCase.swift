import Foundation

/// Returns the current set of insights for the user, filtered by the
/// dismissal store so kinds the user explicitly hid don't reappear until
/// their dismissal window expires.
public struct GenerateInsightsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let generator: any InsightsGenerator
    private let dismissals: any InsightDismissalStore
    private let clock: any OrbitClock

    public init(
        memories: any MemoryRepository,
        generator: any InsightsGenerator,
        dismissals: any InsightDismissalStore,
        clock: any OrbitClock
    ) {
        self.memories = memories
        self.generator = generator
        self.dismissals = dismissals
        self.clock = clock
    }

    public func callAsFunction() async throws -> [SmartInsight] {
        let now = clock.now()
        let all = try await memories.list(filter: .all)
        let generated = await generator.generate(from: all, now: now)
        return generated.filter { !dismissals.isDismissed($0.kind, now: now) }
    }

    /// Convenience for dismissing from a view layer that already has the use
    /// case in hand.
    public func dismiss(_ kind: SmartInsight.Kind, for duration: TimeInterval = 60 * 60 * 24 * 30) {
        dismissals.dismiss(kind, until: clock.now().addingTimeInterval(duration))
    }
}
