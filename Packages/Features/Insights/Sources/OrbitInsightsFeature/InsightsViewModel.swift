import Foundation
import Observation
import OrbitDomain

/// Owns the list of insights for the patterns surface and the rotating
/// preview card on Home. Recomputes from the repository on demand; the
/// underlying engine is cheap but we only refresh when the host view tells
/// us to (e.g. on appear, after a capture).
@MainActor
@Observable
public final class InsightsViewModel {
    public private(set) var insights: [SmartInsight] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: String?

    private let generate: GenerateInsightsUseCase

    public init(generate: GenerateInsightsUseCase) {
        self.generate = generate
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            insights = try await generate()
            error = nil
        } catch {
            self.error = String(describing: error)
        }
    }

    public func dismiss(_ kind: SmartInsight.Kind) async {
        generate.dismiss(kind)
        await load()
    }

    /// The single insight to surface on Home. Picks the most "interesting" by
    /// preferred kind order so the surface stays predictable from day to day
    /// rather than randomly rotating.
    public var primaryInsight: SmartInsight? {
        let priority: [SmartInsight.Kind] = [.topEntity, .trendingCategory, .weeklyVolume, .dayOfWeek]
        for kind in priority {
            if let match = insights.first(where: { $0.kind == kind }) {
                return match
            }
        }
        return insights.first
    }
}
