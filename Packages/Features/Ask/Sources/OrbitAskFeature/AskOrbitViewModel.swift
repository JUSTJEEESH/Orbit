import Foundation
import Observation
import OrbitDomain
import OrbitKit

/// Owns the Ask Orbit sheet's state machine: idle (waiting for a
/// question), thinking (model is running), answered (display narrative +
/// sources), failed. Single-turn by design — premium feel is about the
/// quality of the answer, not the length of the thread.
@MainActor
@Observable
public final class AskOrbitViewModel {
    public enum State: Equatable {
        case idle
        case thinking
        case answered(AskOrbitAnswer)
        case failed(String)
    }

    public var question: String = ""
    public private(set) var state: State = .idle
    public private(set) var sourceMemories: [Memory] = []

    private let ask: AskOrbitUseCase
    private let memories: any MemoryRepository
    private var inflight: Task<Void, Never>?

    public init(ask: AskOrbitUseCase, memories: any MemoryRepository) {
        self.ask = ask
        self.memories = memories
    }

    public func submit() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inflight?.cancel()
        Haptics.play(.tap)
        state = .thinking
        sourceMemories = []

        inflight = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let answer = try await ask(question: trimmed)
                guard !Task.isCancelled else { return }
                self.state = .answered(answer)
                self.sourceMemories = await self.fetchSources(answer.sourceMemoryIDs)
                Haptics.play(.success)
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed("Couldn't answer. Try again.")
                Haptics.play(.failure)
            }
        }
    }

    public func reset() {
        inflight?.cancel()
        inflight = nil
        question = ""
        state = .idle
        sourceMemories = []
    }

    private func fetchSources(_ ids: [UUID]) async -> [Memory] {
        var ordered: [Memory] = []
        for id in ids {
            if let memory = try? await memories.memory(with: id) {
                ordered.append(memory)
            }
        }
        return ordered
    }
}
