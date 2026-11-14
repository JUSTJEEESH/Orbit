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
