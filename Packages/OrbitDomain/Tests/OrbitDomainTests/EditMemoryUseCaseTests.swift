import Foundation
import Testing
@testable import OrbitDomain

@Suite("Editing memories")
struct EditMemoryUseCaseTests {
    private let clock = FixedClock(Date(timeIntervalSince1970: 2_000_000_000))

    private func completedAI() -> MemoryAIMetadata {
        MemoryAIMetadata(
            status: .complete, summary: "Passport renewal.", category: "travel", priority: .normal,
            extractedDates: [], extractedPeople: [], extractedLocations: []
        )
    }

    @Test func editingTextRequeuesEnrichment() async throws {
        let repo = InMemoryMemoryRepository()
        let memory = Memory(content: .text("Renew passport"), createdAt: .now, updatedAt: .now, ai: completedAI())
        try await repo.save(memory)

        let result = try await EditMemoryUseCase(repository: repo, clock: clock)(
            id: memory.id, text: "Renew passport and license", tagNames: []
        )

        #expect(result.contentChanged)
        let saved = try #require(try await repo.memory(with: memory.id))
        #expect(saved.content == .text("Renew passport and license"))
        #expect(saved.ai.status == .pending)
        #expect(saved.updatedAt == clock.now())
    }

    @Test func tagOnlyEditKeepsAIMetadataAndTagIdentity() async throws {
        let repo = InMemoryMemoryRepository()
        let travel = Tag(name: "travel", origin: .ai)
        let memory = Memory(content: .text("Renew passport"), createdAt: .now, updatedAt: .now, tags: [travel], ai: completedAI())
        try await repo.save(memory)

        let result = try await EditMemoryUseCase(repository: repo, clock: clock)(
            id: memory.id, text: "Renew passport", tagNames: ["Travel", "urgent", " ", "urgent"]
        )

        #expect(!result.contentChanged)
        let saved = try #require(try await repo.memory(with: memory.id))
        #expect(saved.ai.status == .complete)
        #expect(saved.tags.map(\.name) == ["travel", "urgent"])
        #expect(saved.tags.first == travel)
        #expect(saved.tags.last?.origin == .user)
    }

    @Test func voiceNoteEditKeepsDurationAndBlankClearsTranscript() {
        let voice = MemoryContent.voiceNote(transcript: "hello", duration: 12)
        #expect(voice.replacingEditableText("hello there") == .voiceNote(transcript: "hello there", duration: 12))
        #expect(voice.replacingEditableText("   ") == .voiceNote(transcript: nil, duration: 12))
    }

    @Test func linkEditChangesTitleOnly() throws {
        let url = try #require(URL(string: "https://example.com"))
        let link = MemoryContent.link(url: url, title: "Old", summary: "Summary")
        #expect(link.editableText == "Old")
        #expect(link.replacingEditableText("New") == .link(url: url, title: "New", summary: "Summary"))
    }

    @Test func missingMemoryThrows() async {
        await #expect(throws: OrbitError.self) {
            try await EditMemoryUseCase(repository: InMemoryMemoryRepository(), clock: clock)(id: UUID(), text: "x", tagNames: [])
        }
    }
}
