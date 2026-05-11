import Foundation
import Testing
@testable import OrbitDomain

struct EnrichMemoryUseCaseTests {

    @Test func writesCompletedMetadataOnSuccess() async throws {
        let clock = FixedClock(Date(timeIntervalSince1970: 1_000))
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("Renew passport before July trip"),
                            createdAt: clock.now(),
                            updatedAt: clock.now())
        try await repo.save(memory)

        let result = ClassificationResult(
            kind: .text,
            category: "travel",
            suggestedTags: ["passport", "travel"],
            priority: .high,
            summary: "Renew passport before the July trip.",
            extractedDates: [Date(timeIntervalSince1970: 2_000)],
            extractedPeople: [],
            extractedLocations: []
        )
        let ai = StubAIService(classification: result)
        let enrich = EnrichMemoryUseCase(ai: ai, memories: repo, clock: clock)

        await enrich(memoryID: memory.id)

        let updated = try await repo.memory(with: memory.id)
        #expect(updated?.ai.status == .complete)
        #expect(updated?.ai.category == "travel")
        #expect(updated?.ai.priority == .high)
        #expect(updated?.ai.summary == "Renew passport before the July trip.")
        #expect(updated?.tags.map(\.name).contains("passport") == true)
        #expect(updated?.tags.map(\.name).contains("travel") == true)
        #expect(updated?.tags.first(where: { $0.name == "passport" })?.origin == .ai)
    }

    @Test func setsFailedStatusOnError() async throws {
        let clock = SystemClock()
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("hello"),
                            createdAt: clock.now(),
                            updatedAt: clock.now())
        try await repo.save(memory)

        let ai = StubAIService(classification: nil) // throws on classify
        let enrich = EnrichMemoryUseCase(ai: ai, memories: repo, clock: clock)

        await enrich(memoryID: memory.id)

        let updated = try await repo.memory(with: memory.id)
        #expect(updated?.ai.status == .failed)
    }

    @Test func noopWhenMemoryMissing() async {
        let repo = InMemoryMemoryRepository()
        let ai = StubAIService(classification: .init(
            kind: .text, category: "note", suggestedTags: [], priority: .normal,
            summary: nil, extractedDates: [], extractedPeople: [], extractedLocations: []
        ))
        let enrich = EnrichMemoryUseCase(ai: ai, memories: repo, clock: SystemClock())

        await enrich(memoryID: UUID()) // should not throw
    }
}

private actor StubAIService: AIService {
    let classification: ClassificationResult?
    init(classification: ClassificationResult?) { self.classification = classification }

    func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        guard let classification else { throw OrbitError.aiUnavailable }
        return classification
    }
    func summarize(_ memory: Memory) async throws -> String { "" }
    func extractTasks(from memory: Memory) async throws -> [MemoryTask] { [] }
    func embed(_ text: String) async throws -> [Float] { [] }
    func dailyRecap(memories: [Memory], date: Date) async throws -> DailyRecapDraft {
        DailyRecapDraft(narrative: "", mood: nil, highlightIDs: [])
    }
}
