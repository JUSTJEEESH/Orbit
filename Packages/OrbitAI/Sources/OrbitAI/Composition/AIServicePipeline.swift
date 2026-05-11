import Foundation
import OrbitDomain

/// Tries the primary `AIService`; if it throws, falls back to the next. Used
/// to compose `FoundationModelsAdapter` (on-device) with `CloudAIService`
/// (proxy) without coupling either to the other.
public actor AIServicePipeline: AIService {
    private let services: [any AIService]

    public init(_ services: [any AIService]) {
        self.services = services
    }

    public func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        try await firstSuccess { try await $0.classify(raw) }
    }

    public func summarize(_ memory: Memory) async throws -> String {
        try await firstSuccess { try await $0.summarize(memory) }
    }

    public func extractTasks(from memory: Memory) async throws -> [MemoryTask] {
        try await firstSuccess { try await $0.extractTasks(from: memory) }
    }

    public func embed(_ text: String) async throws -> [Float] {
        try await firstSuccess { try await $0.embed(text) }
    }

    private func firstSuccess<T>(
        _ run: (any AIService) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for service in services {
            do { return try await run(service) }
            catch { lastError = error }
        }
        throw lastError ?? OrbitError.aiUnavailable
    }
}
