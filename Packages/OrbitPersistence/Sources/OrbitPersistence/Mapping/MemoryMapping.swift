import Foundation
import SwiftData
import OrbitDomain

// MARK: - Memory <-> MemoryEntity

extension MemoryEntity {
    /// Build a fresh entity from a domain memory. `resolvedTags` and
    /// `resolvedMedia` must already be inserted into the same `ModelContext`
    /// the caller plans to insert the returned entity into.
    static func make(
        from memory: Memory,
        resolvedTags: [TagEntity],
        resolvedMedia: [MediaAssetEntity]
    ) -> MemoryEntity {
        let entity = MemoryEntity(id: memory.id)
        entity.apply(from: memory, resolvedTags: resolvedTags, resolvedMedia: resolvedMedia)
        return entity
    }

    /// Overwrite an existing entity in-place from a domain memory.
    func apply(
        from memory: Memory,
        resolvedTags: [TagEntity],
        resolvedMedia: [MediaAssetEntity]
    ) {
        self.id = memory.id
        self.createdAt = memory.createdAt
        self.updatedAt = memory.updatedAt
        self.linkedTaskIDs = memory.linkedTaskIDs
        self.embedding = memory.embedding
        self.applyContent(memory.content)
        self.applyAI(memory.ai)
        self.tags = resolvedTags
        self.media = resolvedMedia
    }

    func toDomain() -> Memory {
        Memory(
            id: id,
            content: decodeContent(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            tags: (tags ?? []).map { Tag(id: $0.id, name: $0.name, origin: Tag.Origin(rawValue: $0.origin) ?? .user) },
            media: (media ?? []).map {
                MediaAsset(
                    id: $0.id,
                    kind: MediaAsset.Kind(rawValue: $0.kind) ?? .image,
                    filename: $0.filename,
                    byteSize: $0.byteSize,
                    createdAt: $0.createdAt
                )
            },
            ai: decodeAI(),
            linkedTaskIDs: linkedTaskIDs,
            embedding: embedding
        )
    }

    private func applyContent(_ content: MemoryContent) {
        self.contentKind = content.kind.rawValue
        self.textContent = nil
        self.voiceTranscript = nil
        self.voiceDuration = 0
        self.imageCaption = nil
        self.linkURLString = nil
        self.linkTitle = nil
        self.linkSummary = nil
        self.screenshotOCRText = nil
        self.locationName = nil
        self.latitude = 0
        self.longitude = 0

        switch content {
        case .text(let s):
            self.textContent = s
        case .voiceNote(let transcript, let duration):
            self.voiceTranscript = transcript
            self.voiceDuration = duration
        case .image(let caption):
            self.imageCaption = caption
        case .link(let url, let title, let summary):
            self.linkURLString = url.absoluteString
            self.linkTitle = title
            self.linkSummary = summary
        case .screenshot(let ocr):
            self.screenshotOCRText = ocr
        case .location(let name, let latitude, let longitude):
            self.locationName = name
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    private func decodeContent() -> MemoryContent {
        switch MemoryContentKind(rawValue: contentKind) ?? .text {
        case .text:
            return .text(textContent ?? "")
        case .voiceNote:
            return .voiceNote(transcript: voiceTranscript, duration: voiceDuration)
        case .image:
            return .image(caption: imageCaption)
        case .link:
            let url = URL(string: linkURLString ?? "") ?? URL(string: "about:blank")!
            return .link(url: url, title: linkTitle, summary: linkSummary)
        case .screenshot:
            return .screenshot(ocrText: screenshotOCRText)
        case .location:
            return .location(name: locationName, latitude: latitude, longitude: longitude)
        }
    }

    private func applyAI(_ ai: MemoryAIMetadata) {
        self.aiStatus = ai.status.rawValue
        self.aiSummary = ai.summary
        self.aiCategory = ai.category
        self.aiPriority = ai.priority.rawValue
        self.aiExtractedDates = ai.extractedDates
        self.aiExtractedPeople = ai.extractedPeople
        self.aiExtractedLocations = ai.extractedLocations
        // Empty signals are persisted as nil so we don't write a JSON blob
        // on every text-only row.
        if ai.signals.isEmpty {
            self.signalsJSON = nil
        } else {
            self.signalsJSON = try? JSONEncoder().encode(ai.signals)
        }
    }

    private func decodeAI() -> MemoryAIMetadata {
        let signals: ExtractedSignals = {
            guard let data = signalsJSON,
                  let decoded = try? JSONDecoder().decode(ExtractedSignals.self, from: data)
            else { return .empty }
            return decoded
        }()
        return MemoryAIMetadata(
            status: MemoryAIMetadata.ProcessingStatus(rawValue: aiStatus) ?? .pending,
            summary: aiSummary,
            category: aiCategory,
            priority: MemoryAIMetadata.Priority(rawValue: aiPriority) ?? .normal,
            extractedDates: aiExtractedDates,
            extractedPeople: aiExtractedPeople,
            extractedLocations: aiExtractedLocations,
            signals: signals
        )
    }
}

// MARK: - MemoryTask <-> MemoryTaskEntity

extension MemoryTaskEntity {
    static func make(from task: MemoryTask) -> MemoryTaskEntity {
        let entity = MemoryTaskEntity(id: task.id, title: task.title, createdAt: task.createdAt)
        entity.apply(from: task)
        return entity
    }

    func apply(from task: MemoryTask) {
        self.id = task.id
        self.title = task.title
        self.notes = task.notes
        self.isCompleted = task.isCompleted
        self.dueDate = task.dueDate
        self.priority = task.priority.rawValue
        self.linkedMemoryID = task.linkedMemoryID
        self.sourceHintID = task.sourceHintID
        self.remindersIdentifier = task.remindersIdentifier
        self.createdAt = task.createdAt
        self.completedAt = task.completedAt
    }

    func toDomain() -> MemoryTask {
        MemoryTask(
            id: id,
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            dueDate: dueDate,
            priority: MemoryAIMetadata.Priority(rawValue: priority) ?? .normal,
            linkedMemoryID: linkedMemoryID,
            sourceHintID: sourceHintID,
            remindersIdentifier: remindersIdentifier,
            createdAt: createdAt,
            completedAt: completedAt
        )
    }
}

// MARK: - AIInsight <-> AIInsightEntity

extension AIInsightEntity {
    static func make(from insight: AIInsight) -> AIInsightEntity {
        let entity = AIInsightEntity(
            id: insight.id,
            kind: insight.kind.rawValue,
            headline: insight.headline,
            generatedAt: insight.generatedAt
        )
        entity.detail = insight.detail
        entity.relatedMemoryIDs = insight.relatedMemoryIDs
        entity.seenAt = insight.seenAt
        return entity
    }

    func toDomain() -> AIInsight {
        AIInsight(
            id: id,
            kind: AIInsight.Kind(rawValue: kind) ?? .resurfacing,
            headline: headline,
            detail: detail,
            relatedMemoryIDs: relatedMemoryIDs,
            generatedAt: generatedAt,
            seenAt: seenAt
        )
    }
}
