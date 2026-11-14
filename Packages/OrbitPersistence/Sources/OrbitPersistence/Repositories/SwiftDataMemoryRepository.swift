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
        let media = buildMedia(memory.media, reusing: entity.media ?? [])
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

    /// Deletes object by object rather than with `delete(model:)`: bulk
    /// deletes bypass iCloud mirroring, so with sync on the rows would come
    /// back from iCloud (and account deletion wouldn't reach the cloud copy).
    public func deleteAll() async throws {
        for entity in try modelContext.fetch(FetchDescriptor<MemoryEntity>()) {
            modelContext.delete(entity)
        }
        for entity in try modelContext.fetch(FetchDescriptor<TagEntity>()) {
            modelContext.delete(entity)
        }
        for entity in try modelContext.fetch(FetchDescriptor<MediaAssetEntity>()) {
            modelContext.delete(entity)
        }
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
        // The limit can only go to the store when no Swift-side filter runs
        // afterwards. Otherwise it must apply to the *filtered* rows: 1.x
        // limited first, so `limit: 1` returned nothing whenever the newest
        // memory was a sealed time capsule (blanking the Recent widget).
        let filtersInSwift = !filter.includeSealed
            || filter.trash != .included
            || !filter.kinds.isEmpty
            || !filter.tagNames.isEmpty
            || filter.dateRange != nil
            || !(filter.query ?? "").isEmpty
        if let limit = filter.limit, !filtersInSwift { descriptor.fetchLimit = limit }
        var results = try modelContext.fetch(descriptor)

        // We post-filter complex predicates (kinds set, tag-name set, free text)
        // in Swift because SwiftData predicates around Set membership and
        // joined relationship attributes are still rough.
        if filter.trash != .included {
            results = results.filter { filter.admitsTrashState(of: $0.deletedAt) }
        }
        if !filter.includeSealed {
            let now = Date()
            results = results.filter { entity in
                guard let surfaceDate = entity.surfaceDate else { return true }
                return surfaceDate <= now
            }
        }
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
        if let limit = filter.limit, filtersInSwift, results.count > limit {
            results = Array(results.prefix(limit))
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

    /// Resolves media rows for a save/update. Rows already attached to the
    /// memory are reused by `id`: creating fresh ones on every update (as
    /// 1.x did) left an orphaned duplicate row per update — enrichment alone
    /// updates each memory two or three times. Detached rows are left in
    /// place rather than deleted; they still name files on disk.
    private func buildMedia(_ assets: [MediaAsset], reusing existing: [MediaAssetEntity] = []) -> [MediaAssetEntity] {
        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return assets.map { asset in
            if let reused = existingByID[asset.id] {
                reused.kind = asset.kind.rawValue
                reused.filename = asset.filename
                reused.byteSize = asset.byteSize
                reused.createdAt = asset.createdAt
                return reused
            }
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
