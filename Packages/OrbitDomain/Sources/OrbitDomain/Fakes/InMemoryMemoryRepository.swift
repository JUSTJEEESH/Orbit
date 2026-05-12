import Foundation

/// In-memory `MemoryRepository`. Use for SwiftUI previews, unit tests, and as
/// a placeholder before real persistence wires up. Thread-safe via an actor.
public actor InMemoryMemoryRepository: MemoryRepository {
    private var storage: [UUID: Memory] = [:]

    public init(seed: [Memory] = []) {
        for memory in seed { storage[memory.id] = memory }
    }

    public func save(_ memory: Memory) async throws {
        storage[memory.id] = memory
    }

    public func update(_ memory: Memory) async throws {
        guard storage[memory.id] != nil else { throw OrbitError.notFound }
        storage[memory.id] = memory
    }

    public func delete(id: UUID) async throws {
        storage.removeValue(forKey: id)
    }

    public func deleteAll() async throws {
        storage.removeAll()
    }

    public func memory(with id: UUID) async throws -> Memory? {
        storage[id]
    }

    public func list(filter: MemoryFilter) async throws -> [Memory] {
        let filtered = storage.values.filter { matches($0, filter) }
        let sorted = sortedMemories(Array(filtered), by: filter.sort)
        if let limit = filter.limit { return Array(sorted.prefix(limit)) }
        return sorted
    }

    public func count(filter: MemoryFilter) async throws -> Int {
        storage.values.filter { matches($0, filter) }.count
    }

    private func matches(_ memory: Memory, _ filter: MemoryFilter) -> Bool {
        if !filter.includeSealed, memory.isSealed() { return false }
        if !filter.kinds.isEmpty, !filter.kinds.contains(memory.content.kind) { return false }
        if !filter.tagNames.isEmpty {
            let names = Set(memory.tags.map(\.name))
            if names.intersection(filter.tagNames).isEmpty { return false }
        }
        if let range = filter.dateRange, !range.contains(memory.createdAt) { return false }
        if let query = filter.query?.lowercased(), !query.isEmpty {
            let haystack = searchableText(memory).lowercased()
            if !haystack.contains(query) { return false }
        }
        return true
    }

    private func searchableText(_ memory: Memory) -> String {
        var parts: [String] = []
        switch memory.content {
        case .text(let s):                                   parts.append(s)
        case .voiceNote(let t, _):                           if let t { parts.append(t) }
        case .image(let caption):                            if let caption { parts.append(caption) }
        case .link(let url, let title, let summary):
            parts.append(url.absoluteString)
            if let title { parts.append(title) }
            if let summary { parts.append(summary) }
        case .screenshot(let ocr):                           if let ocr { parts.append(ocr) }
        case .location(let name, _, _):                      if let name { parts.append(name) }
        }
        parts.append(contentsOf: memory.tags.map(\.name))
        if let summary = memory.ai.summary { parts.append(summary) }
        return parts.joined(separator: " ")
    }

    private func sortedMemories(_ memories: [Memory], by sort: MemoryFilter.Sort) -> [Memory] {
        switch sort {
        case .newestFirst:    return memories.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:    return memories.sorted { $0.createdAt < $1.createdAt }
        case .priorityFirst:  return memories.sorted { $0.ai.priority > $1.ai.priority }
        }
    }
}
