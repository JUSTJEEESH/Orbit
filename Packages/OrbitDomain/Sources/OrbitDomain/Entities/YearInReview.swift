import Foundation

/// The annual reflection surface. Computed by `GenerateYearInReviewUseCase`
/// from the year's memories — totals, top entities, monthly cadence, and a
/// hand-picked set of highlight memories used by the carousel + memory-rain
/// closing scene.
public struct YearInReview: Sendable, Hashable {
    public let year: Int
    public let totalCaptures: Int
    public let kindBreakdown: [KindStat]
    public let topCategory: NamedCount?
    public let topPerson: NamedCount?
    public let topPlace: NamedCount?
    public let mostActiveMonth: Int?
    public let monthlyCounts: [MonthlyCount]
    public let highlights: [Memory]
    public let generatedAt: Date

    public init(
        year: Int,
        totalCaptures: Int,
        kindBreakdown: [KindStat],
        topCategory: NamedCount?,
        topPerson: NamedCount?,
        topPlace: NamedCount?,
        mostActiveMonth: Int?,
        monthlyCounts: [MonthlyCount],
        highlights: [Memory],
        generatedAt: Date
    ) {
        self.year = year
        self.totalCaptures = totalCaptures
        self.kindBreakdown = kindBreakdown
        self.topCategory = topCategory
        self.topPerson = topPerson
        self.topPlace = topPlace
        self.mostActiveMonth = mostActiveMonth
        self.monthlyCounts = monthlyCounts
        self.highlights = highlights
        self.generatedAt = generatedAt
    }

    public var isEmpty: Bool { totalCaptures == 0 }

    public struct KindStat: Sendable, Hashable, Identifiable {
        public let kind: MemoryContentKind
        public let count: Int
        public var id: String { kind.rawValue }

        public init(kind: MemoryContentKind, count: Int) {
            self.kind = kind
            self.count = count
        }
    }

    public struct NamedCount: Sendable, Hashable {
        public let name: String
        public let count: Int

        public init(name: String, count: Int) {
            self.name = name
            self.count = count
        }
    }

    public struct MonthlyCount: Sendable, Hashable, Identifiable {
        public let month: Int      // 1...12
        public let count: Int
        public var id: Int { month }

        public init(month: Int, count: Int) {
            self.month = month
            self.count = count
        }
    }
}
