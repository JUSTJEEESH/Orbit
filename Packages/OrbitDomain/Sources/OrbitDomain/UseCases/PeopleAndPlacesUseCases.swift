import Foundation

/// A person or place mentioned across the user's memories.
public struct MentionedEntity: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable {
        case person
        case place
    }

    public var id: String { "\(kind.rawValue):\(key)" }
    public let kind: Kind
    /// The most common spelling, for display.
    public let name: String
    /// Case- and whitespace-insensitive identity.
    public let key: String
    public let memoryCount: Int
    public let lastMentioned: Date
    /// People only: the latest memory that was time spent with them
    /// ("had dinner with Sam"), as opposed to merely mentioning them.
    public let lastContact: Date?

    public init(kind: Kind, name: String, key: String, memoryCount: Int, lastMentioned: Date, lastContact: Date? = nil) {
        self.kind = kind
        self.name = name
        self.key = key
        self.memoryCount = memoryCount
        self.lastMentioned = lastMentioned
        self.lastContact = lastContact
    }

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

extension Memory {
    /// People this memory mentions (from on-device entity extraction).
    func mentionedNames(of kind: MentionedEntity.Kind) -> [String] {
        switch kind {
        case .person:
            return ai.extractedPeople
        case .place:
            var names = ai.extractedLocations
            if case .location(let name?, _, _) = content { names.append(name) }
            return names
        }
    }

    /// The words a memory holds, for on-device text analysis.
    var analyzableText: String {
        switch content {
        case .text(let text):                 return text
        case .voiceNote(let transcript, _):   return transcript ?? ""
        case .image(let caption):             return caption ?? ""
        case .link(_, let title, let summary): return [title, summary].compactMap { $0 }.joined(separator: " ")
        case .screenshot(let text):           return text ?? ""
        case .location(let name, _, _):       return name ?? ""
        }
    }
}

/// Everyone and everywhere the user's memories mention, most mentioned
/// first. Lets people browse their memories by who and where, without
/// having to ask or search.
public struct ListMentionedEntitiesUseCase: Sendable {
    private let repository: any MemoryRepository

    public init(repository: any MemoryRepository) {
        self.repository = repository
    }

    public func callAsFunction(kind: MentionedEntity.Kind, limit: Int? = nil) async throws -> [MentionedEntity] {
        let memories = try await repository.list(filter: .all)
        return Self.summarize(memories, kind: kind, limit: limit)
    }

    static func summarize(_ memories: [Memory], kind: MentionedEntity.Kind, limit: Int?) -> [MentionedEntity] {
        struct Tally {
            var spellings: [String: Int] = [:]
            var memoryIDs: Set<UUID> = []
            var last: Date = .distantPast
            var lastContact: Date?
        }
        var tallies: [String: Tally] = [:]
        for memory in memories {
            for raw in memory.mentionedNames(of: kind) {
                let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = MentionedEntity.key(for: name)
                guard name.count > 1 else { continue }
                var tally = tallies[key, default: Tally()]
                tally.spellings[name, default: 0] += 1
                tally.memoryIDs.insert(memory.id)
                tally.last = max(tally.last, memory.createdAt)
                if kind == .person,
                   memory.createdAt > (tally.lastContact ?? .distantPast),
                   ContactMomentDetector.isContact(with: name, in: memory.analyzableText) {
                    tally.lastContact = memory.createdAt
                }
                tallies[key] = tally
            }
        }
        let entities = tallies.map { key, tally in
            MentionedEntity(
                kind: kind,
                name: tally.spellings.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key ?? key,
                key: key,
                memoryCount: tally.memoryIDs.count,
                lastMentioned: tally.last,
                lastContact: tally.lastContact
            )
        }
        .sorted { ($0.memoryCount, $0.lastMentioned) > ($1.memoryCount, $1.lastMentioned) }
        return limit.map { Array(entities.prefix($0)) } ?? entities
    }
}

/// Every memory mentioning one person or place, newest first.
public struct ListMemoriesMentioningUseCase: Sendable {
    private let repository: any MemoryRepository

    public init(repository: any MemoryRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ entity: MentionedEntity) async throws -> [Memory] {
        try await repository.list(filter: MemoryFilter(sort: .newestFirst)).filter { memory in
            memory.mentionedNames(of: entity.kind).contains { MentionedEntity.key(for: $0) == entity.key }
        }
    }
}
