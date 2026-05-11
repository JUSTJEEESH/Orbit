import Foundation
import SwiftData
import OrbitDomain

@ModelActor
public actor SwiftDataMemoryRepository: MemoryRepository {

    public func save(_ memory: Memory) async throws {
        let tags = resolveTags(memory.tags)
        let media = buildMedia(memory.media)
        let entity = MemoryEntity.make(from: memory, resolvedTags: tags, resolvedMedia: media)
        modelContext.insert(entity)
        try modelContext.save()
    }

    public func update(_ memory: Memory) async throws {
        let id = memory.id
        var descriptor = FetchDescriptor<MemoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw OrbitError.notFound
        }
        let tags = resolveTags(memory.tags)
        let media = buildMedia(memory.media)
        entity.apply(from: memory, resolvedTags: tags, resolvedMedia: media)
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        var descriptor = FetchDescriptor<MemoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw OrbitError.notFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }

    public func deleteAll() async throws {
        try modelContext.delete(model: MemoryEntity.self)
        try modelContext.delete(model: TagEntity.self)
        try modelContext.delete(model: MediaAssetEntity.self)
        try modelContext.save()
    }

    public func memory(with id: UUID) async throws -> Memory? {
        var descriptor = FetchDescriptor<MemoryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func list(filter: MemoryFilter) async throws -> [Memory] {
        try fetchEntities(filter: filter).map { $0.toDomain() }
    }

    public func count(filter: MemoryFilter) async throws -> Int {
        try fetchEntities(filter: filter).count
    }

    // MARK: - Helpers

    private func fetchEntities(filter: MemoryFilter) throws -> [MemoryEntity] {
        var descriptor = FetchDescriptor<MemoryEntity>()
        descriptor.sortBy = sortDescriptors(for: filter.sort)
        if let limit = filter.limit { descriptor.fetchLimit = limit }
        var results = try modelContext.fetch(descriptor)

        // We post-filter complex predicates (kinds set, tag-name set, free text)
        // in Swift because SwiftData predicates around Set membership and
        // joined relationship attributes are still rough.
        if !filter.kinds.isEmpty {
            let kindRaw = Set(filter.kinds.map(\.rawValue))
            results = results.filter { kindRaw.contains($0.contentKind) }
        }
        if !filter.tagNames.isEmpty {
            results = results.filter { entity in
                let names = Set((entity.tags ?? []).map(\.name))
                return !names.intersection(filter.tagNames).isEmpty
            }
        }
        if let range = filter.dateRange {
            results = results.filter { range.contains($0.createdAt) }
        }
        if let query = filter.query?.lowercased(), !query.isEmpty {
            results = results.filter { entity in
                let haystack = entity.searchableText.lowercased()
                return haystack.contains(query)
            }
        }
        return results
    }

    private func sortDescriptors(for sort: MemoryFilter.Sort) -> [SortDescriptor<MemoryEntity>] {
        switch sort {
        case .newestFirst:    return [SortDescriptor(\.createdAt, order: .reverse)]
        case .oldestFirst:    return [SortDescriptor(\.createdAt, order: .forward)]
        case .priorityFirst:  return [SortDescriptor(\.aiPriority, order: .reverse),
                                      SortDescriptor(\.createdAt, order: .reverse)]
        }
    }

    private func resolveTags(_ tags: [Tag]) -> [TagEntity] {
        tags.map { tag in
            let name = tag.name
            let descriptor = FetchDescriptor<TagEntity>(predicate: #Predicate { $0.name == name })
            if let existing = try? modelContext.fetch(descriptor).first {
                return existing
            }
            let entity = TagEntity(id: tag.id, name: tag.name, origin: tag.origin.rawValue)
            modelContext.insert(entity)
            return entity
        }
    }

    private func buildMedia(_ assets: [MediaAsset]) -> [MediaAssetEntity] {
        assets.map { asset in
            let entity = MediaAssetEntity(
                id: asset.id,
                kind: asset.kind.rawValue,
                filename: asset.filename,
                byteSize: asset.byteSize,
                createdAt: asset.createdAt
            )
            modelContext.insert(entity)
            return entity
        }
    }
}

private extension MemoryEntity {
    var searchableText: String {
        var parts: [String] = []
        if let textContent { parts.append(textContent) }
        if let voiceTranscript { parts.append(voiceTranscript) }
        if let imageCaption { parts.append(imageCaption) }
        if let linkURLString { parts.append(linkURLString) }
        if let linkTitle { parts.append(linkTitle) }
        if let linkSummary { parts.append(linkSummary) }
        if let screenshotOCRText { parts.append(screenshotOCRText) }
        if let locationName { parts.append(locationName) }
        if let aiSummary { parts.append(aiSummary) }
        parts.append(contentsOf: (tags ?? []).map(\.name))
        return parts.joined(separator: " ")
    }
}
