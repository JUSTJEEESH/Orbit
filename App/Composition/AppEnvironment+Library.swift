import Foundation
import OrbitPersistence

extension AppEnvironment {
    /// Builds the "Export Everything" archive: a Markdown journal, a JSON
    /// file with every field, and the original photos and recordings.
    func exportLibrary() async throws -> URL {
        let storage = mediaStorage
        return try await LibraryExporter.export(
            memories: memories,
            tasks: tasks,
            mediaURL: { filename in await storage.url(forFilename: filename) },
            now: clock.now()
        )
    }
}

extension AppEnvironment {
    /// Saves a user's edit to a memory's text and tags. A text change makes
    /// the AI metadata stale, so it's re-enriched; Spotlight is refreshed
    /// either way.
    func editMemory(id: UUID, text: String, tagNames: [String]) async throws {
        let result = try await editMemoryUseCase(id: id, text: text, tagNames: tagNames)
        await spotlight.index(result.memory)
        memoriesDidChange()
        if result.contentChanged {
            scheduleEnrichment(for: id)
        }
    }
}

extension AppEnvironment {
    /// Imports memories from Day One, text/Markdown files or an Orbit
    /// export, then organizes them in the background like new captures.
    /// - Returns: a short summary for Settings.
    func importLibrary(from urls: [URL]) async throws -> String {
        let summary = try await LibraryImporter.importFiles(urls, memories: memories, tasks: tasks, now: clock.now())
        memoriesDidChange()
        let imported = summary.importedMemoryIDs
        Task { @MainActor [weak self] in
            guard let self else { return }
            for id in imported {
                await self.enrichMemory(memoryID: id)
                if let memory = try? await self.memories.memory(with: id) {
                    await self.spotlight.index(memory)
                }
            }
            if !imported.isEmpty { self.memoriesDidChange() }
        }
        return Self.importMessage(for: summary)
    }

    private static func importMessage(for summary: LibraryImporter.Summary) -> String {
        var parts: [String] = []
        switch summary.importedMemories {
        case 0:  parts.append("No new memories found")
        case 1:  parts.append("Imported 1 memory")
        default: parts.append("Imported \(summary.importedMemories) memories")
        }
        if summary.importedTasks > 0 { parts.append("\(summary.importedTasks) tasks") }
        if summary.skippedDuplicates > 0 { parts.append("\(summary.skippedDuplicates) already in Orbit") }
        if summary.unreadableFiles > 0 { parts.append("\(summary.unreadableFiles) files couldn’t be read") }
        return parts.joined(separator: " · ") + "."
    }
}
