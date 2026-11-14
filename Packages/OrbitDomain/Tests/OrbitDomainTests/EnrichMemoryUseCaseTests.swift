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

    /// A tag the user adds while the model is running must survive the
    /// enrichment write.
    @Test func keepsChangesMadeDuringClassification() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("Renew passport"), createdAt: .now, updatedAt: .now)
        try await repo.save(memory)

        let ai = MidFlightAIService(classification: Self.travelResult) {
            guard var current = try? await repo.memory(with: memory.id) else { return }
            current.tags.append(Tag(name: "urgent", origin: .user))
            try? await repo.update(current)
        }
        await EnrichMemoryUseCase(ai: ai, memories: repo, clock: SystemClock())(memoryID: memory.id)

        let updated = try #require(try await repo.memory(with: memory.id))
        #expect(updated.ai.status == .complete)
        #expect(updated.tags.contains { $0.name == "urgent" && $0.origin == .user })
        #expect(updated.tags.contains { $0.name == "travel" && $0.origin == .ai })
    }

    /// If the text itself changes mid-flight, the result describes stale
    /// text: keep the user's edit and queue the memory for re-enrichment.
    @Test func doesNotOverwriteContentEditedDuringClassification() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("Renew passport"), createdAt: .now, updatedAt: .now)
        try await repo.save(memory)

        let ai = MidFlightAIService(classification: Self.travelResult) {
            guard var current = try? await repo.memory(with: memory.id) else { return }
            current.content = .text("Renew passport and driver's license")
            try? await repo.update(current)
        }
        await EnrichMemoryUseCase(ai: ai, memories: repo, clock: SystemClock())(memoryID: memory.id)

        let updated = try #require(try await repo.memory(with: memory.id))
        #expect(updated.content == .text("Renew passport and driver's license"))
        #expect(updated.ai.status == .pending)
        #expect(updated.ai.summary == nil)
    }

    @Test func memoryDeletedDuringClassificationStaysDeleted() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("temp"), createdAt: .now, updatedAt: .now)
        try await repo.save(memory)

        let ai = MidFlightAIService(classification: Self.travelResult) {
            try? await repo.delete(id: memory.id)
        }
        await EnrichMemoryUseCase(ai: ai, memories: repo, clock: SystemClock())(memoryID: memory.id)

        #expect(try await repo.memory(with: memory.id) == nil)
    }

    private static let travelResult = ClassificationResult(
        kind: .text, category: "travel", suggestedTags: ["travel"], priority: .normal,
        summary: "Passport renewal.", extractedDates: [], extractedPeople: [], extractedLocations: []
    )
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
    func askOrbit(question: String, memories: [Memory]) async throws -> AskOrbitDraft {
        AskOrbitDraft(narrative: "", citationIndices: [])
    }
    func explainConnections(anchor: Memory, related: [Memory]) async throws -> [UUID: String] {
        [:]
    }
}

/// Runs `duringClassify` while "the model is thinking", to simulate the user
/// acting on the memory mid-enrichment.
private actor MidFlightAIService: AIService {
    let classification: ClassificationResult
    let duringClassify: @Sendable () async -> Void
    init(classification: ClassificationResult, duringClassify: @escaping @Sendable () async -> Void) {
        self.classification = classification
        self.duringClassify = duringClassify
    }

    func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        await duringClassify()
        return classification
    }
    func summarize(_ memory: Memory) async throws -> String { "" }
    func extractTasks(from memory: Memory) async throws -> [MemoryTask] { [] }
    func embed(_ text: String) async throws -> [Float] { [] }
    func dailyRecap(memories: [Memory], date: Date) async throws -> DailyRecapDraft {
        DailyRecapDraft(narrative: "", mood: nil, highlightIDs: [])
    }
    func askOrbit(question: String, memories: [Memory]) async throws -> AskOrbitDraft {
        AskOrbitDraft(narrative: "", citationIndices: [])
    }
    func explainConnections(anchor: Memory, related: [Memory]) async throws -> [UUID: String] {
        [:]
    }
}
