import Foundation

/// The single read/write surface for `Memory` aggregates. All persistence
/// concerns — SwiftData, CloudKit, in-memory fakes — implement this protocol.
/// Feature code must never reach past it.
public protocol MemoryRepository: Sendable {
    func save(_ memory: Memory) async throws
    func update(_ memory: Memory) async throws
    func delete(id: UUID) async throws
    func memory(with id: UUID) async throws -> Memory?
    func list(filter: MemoryFilter) async throws -> [Memory]
    func count(filter: MemoryFilter) async throws -> Int
}

public struct MemoryFilter: Sendable, Equatable {
    public var query: String?
    public var kinds: Set<MemoryContentKind>
    public var tagNames: Set<String>
    public var dateRange: ClosedRange<Date>?
    public var limit: Int?
    public var sort: Sort

    public enum Sort: Sendable, Equatable {
        case newestFirst
        case oldestFirst
        case priorityFirst
    }

    public init(
        query: String? = nil,
        kinds: Set<MemoryContentKind> = [],
        tagNames: Set<String> = [],
        dateRange: ClosedRange<Date>? = nil,
        limit: Int? = nil,
        sort: Sort = .newestFirst
    ) {
        self.query = query
        self.kinds = kinds
        self.tagNames = tagNames
        self.dateRange = dateRange
        self.limit = limit
        self.sort = sort
    }

    public static let all = MemoryFilter()
}
