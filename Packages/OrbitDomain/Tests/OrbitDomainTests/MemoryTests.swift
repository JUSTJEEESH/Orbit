import Foundation
import Testing
@testable import OrbitDomain

struct MemoryTests {
    @Test func contentKindIsDerivedFromContent() {
        let memory = Memory(
            content: .text("hello"),
            createdAt: .distantPast,
            updatedAt: .distantPast
        )
        #expect(memory.content.kind == .text)
    }

    @Test func priorityIsComparable() {
        #expect(MemoryAIMetadata.Priority.low < .urgent)
        #expect(MemoryAIMetadata.Priority.high > .normal)
    }

    @Test func defaultAIMetadataIsPending() {
        #expect(MemoryAIMetadata.pending.status == .pending)
        #expect(MemoryAIMetadata.pending.summary == nil)
        #expect(MemoryAIMetadata.pending.priority == .normal)
    }
}
