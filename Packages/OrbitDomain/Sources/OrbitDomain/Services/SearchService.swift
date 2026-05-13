import Foundation

public protocol SearchService: Sendable {
    func search(_ query: SearchQuery) async throws -> [SearchHit]
}

public struct SearchQuery: Sendable, Equatable {
    public var text: String
    public var kinds: Set<MemoryContentKind>
    public var dateRange: ClosedRange<Date>?
    public var limit: Int

    public init(
        text: String,
        kinds: Set<MemoryContentKind> = [],
        dateRange: ClosedRange<Date>? = nil,
        limit: Int = 50
    ) {
        self.text = text
        self.kinds = kinds
        self.dateRange = dateRange
        self.limit = limit
    }
}

public struct SearchHit: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let memoryID: UUID
    public let score: Double
    public let highlight: String?

    public init(id: UUID = UUID(), memoryID: UUID, score: Double, highlight: String?) {
        self.id = id
        self.memoryID = memoryID
        self.score = score
        self.highlight = highlight
    }
}
