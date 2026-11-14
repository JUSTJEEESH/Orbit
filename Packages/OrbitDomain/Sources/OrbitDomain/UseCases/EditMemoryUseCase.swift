import Foundation

public extension MemoryContent {
    /// The text a user can edit for this kind of memory: the note itself, a
    /// voice note's transcript, a photo's caption, a link's title, a
    /// screenshot's recognised text, or a place's name.
    var editableText: String {
        switch self {
        case .text(let s):                  s
        case .voiceNote(let transcript, _): transcript ?? ""
        case .image(let caption):           caption ?? ""
        case .link(_, let title, _):        title ?? ""
        case .screenshot(let ocr):          ocr ?? ""
        case .location(let name, _, _):     name ?? ""
        }
    }

    /// Same content with its editable text replaced. Everything else — the
    /// recording's duration, the link's URL, a place's coordinates — is kept.
    /// Blank text clears optional fields rather than storing "".
    func replacingEditableText(_ newText: String) -> MemoryContent {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        let optional: String? = trimmed.isEmpty ? nil : newText
        switch self {
        case .text:                                     return .text(newText)
        case .voiceNote(_, let duration):               return .voiceNote(transcript: optional, duration: duration)
        case .image:                                    return .image(caption: optional)
        case .link(let url, _, let summary):            return .link(url: url, title: optional, summary: summary)
        case .screenshot:                               return .screenshot(ocrText: optional)
        case .location(_, let latitude, let longitude): return .location(name: optional, latitude: latitude, longitude: longitude)
        }
    }
}

/// Saves a user's edit to a memory's text and tags.
///
/// Works on a fresh read so an edit never clobbers changes made elsewhere
/// (enrichment finishing, another device). When the text changes, the AI
/// metadata no longer describes it, so the memory goes back to `.pending`
/// for re-enrichment; tag-only edits keep it.
public struct EditMemoryUseCase: Sendable {
    public struct Result: Sendable, Equatable {
        public let memory: Memory
        public let contentChanged: Bool
    }

    private let repository: any MemoryRepository
    private let clock: any OrbitClock

    public init(repository: any MemoryRepository, clock: any OrbitClock) {
        self.repository = repository
        self.clock = clock
    }

    public func callAsFunction(id: UUID, text: String, tagNames: [String]) async throws -> Result {
        guard var memory = try await repository.memory(with: id) else { throw OrbitError.notFound }

        let newContent = memory.content.replacingEditableText(text)
        let contentChanged = newContent != memory.content
        memory.content = newContent

        // Keep each surviving tag as-is (id and origin), add new names as
        // user tags, and drop duplicates and blanks.
        var seen: Set<String> = []
        let existingByName = Dictionary(memory.tags.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        memory.tags = tagNames.compactMap { raw in
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            return existingByName[name.lowercased()] ?? Tag(name: name, origin: .user)
        }

        if contentChanged {
            memory.ai.status = .pending
        }
        memory.updatedAt = clock.now()
        try await repository.update(memory)
        return Result(memory: memory, contentChanged: contentChanged)
    }
}
