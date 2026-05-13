import Foundation
import Testing
@testable import OrbitDomain

struct CaptureMemoryUseCaseTests {

    @Test func capturesAndPersistsTextMemory() async throws {
        let clock = FixedClock(Date(timeIntervalSince1970: 1_000))
        let repo = InMemoryMemoryRepository()
        let capture = CaptureMemoryUseCase(repository: repo, clock: clock)

        let memory = try await capture(content: .text("hello world"))

        #expect(memory.createdAt == clock.now())
        #expect(memory.updatedAt == clock.now())
        #expect(memory.ai.status == .pending)

        let stored = try await repo.memory(with: memory.id)
        #expect(stored == memory)
    }

    @Test func capturedMemoryAppearsInList() async throws {
        let repo = InMemoryMemoryRepository()
        let capture = CaptureMemoryUseCase(repository: repo, clock: SystemClock())
        let list = ListMemoriesUseCase(repository: repo)

        _ = try await capture(content: .text("first"))
        _ = try await capture(content: .text("second"))

        let memories = try await list()
        #expect(memories.count == 2)
    }
}
