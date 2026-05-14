import Foundation
import CoreSpotlight
import OrbitDomain

/// Publishes memories into the system Spotlight index so they show up in
/// iPhone-wide search and Siri's contextual suggestions. Best-effort —
/// indexing failures never block capture.
public actor SpotlightIndexer {
    public static let domainIdentifier = "com.joshgreen.orbit.memories"

    private let index: CSSearchableIndex

    public init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    public func index(_ memory: Memory) async {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = Self.title(for: memory)
        attributes.contentDescription = Self.description(for: memory)
        attributes.keywords = Self.keywords(for: memory)
        attributes.contentCreationDate = memory.createdAt
        attributes.contentModificationDate = memory.updatedAt

        let item = CSSearchableItem(
            uniqueIdentifier: memory.id.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributes
        )

        do {
            try await index.indexSearchableItems([item])
        } catch {
            // Spotlight errors are non-fatal. We log nothing here to keep
            // the actor dependency-free.
        }
    }

    public func deindex(memoryID: UUID) async {
        do {
            try await index.deleteSearchableItems(withIdentifiers: [memoryID.uuidString])
        } catch {
            // Non-fatal.
        }
    }

    public func deindexAll() async {
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
        } catch {
            // Non-fatal.
        }
    }

    // MARK: - Composition

    private static func title(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):
            return String(s.prefix(80))
        case .voiceNote(let t, _):
            return t.map { String($0.prefix(80)) } ?? "Voice note"
        case .image(let caption):
            return caption.map { String($0.prefix(80)) } ?? "Photo"
        case .link(_, let title, _):
            return title ?? "Saved link"
        case .screenshot(let ocr):
            return ocr.map { String($0.prefix(80)) } ?? "Screenshot"
        case .location(let name, _, _):
            return name ?? "Saved place"
        }
    }

    private static func description(for memory: Memory) -> String? {
        switch memory.content {
        case .text(let s): return s
        case .voiceNote(let t, _): return t
        case .image(let caption): return caption
        case .link(let url, _, let summary): return summary ?? url.absoluteString
        case .screenshot(let ocr): return ocr
        case .location(_, let lat, let lng): return String(format: "%.4f, %.4f", lat, lng)
        }
    }

    private static func keywords(for memory: Memory) -> [String] {
        var keywords = memory.tags.map(\.name)
        if let category = memory.ai.category { keywords.append(category) }
        keywords.append(contentsOf: memory.ai.extractedPeople)
        keywords.append(contentsOf: memory.ai.extractedLocations)
        return keywords
    }
}
