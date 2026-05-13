import Foundation
import OrbitDomain

/// Placeholder cloud adapter. Real implementation lands when the edge
/// function proxy is provisioned in a later phase. The shape is here today
/// so feature code can compile against the protocol-driven fallback chain
/// without a flag day.
public actor CloudAIService: AIService {
    public init() {}

    public func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        throw OrbitError.aiUnavailable
    }

    public func summarize(_ memory: Memory) async throws -> String {
        throw OrbitError.aiUnavailable
    }

    public func extractTasks(from memory: Memory) async throws -> [MemoryTask] {
        throw OrbitError.aiUnavailable
    }

    public func embed(_ text: String) async throws -> [Float] {
        throw OrbitError.aiUnavailable
    }

    public func dailyRecap(memories: [Memory], date: Date) async throws -> DailyRecapDraft {
        throw OrbitError.aiUnavailable
    }

    public func askOrbit(question: String, memories: [Memory]) async throws -> AskOrbitDraft {
        throw OrbitError.aiUnavailable
    }
}
