import Foundation
import OrbitDomain

/// Deterministic AI service for previews and tests. Returns whatever you
/// configure in the initializer.
public actor MockAIService: AIService {
    public var classification: ClassificationResult
    public var embedding: [Float]
    public var tasks: [MemoryTask]
    public var summary: String

    public init(
        classification: ClassificationResult = .preview,
        embedding: [Float] = [],
        tasks: [MemoryTask] = [],
        summary: String = "Sample summary."
    ) {
        self.classification = classification
        self.embedding = embedding
        self.tasks = tasks
        self.summary = summary
    }

    public func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        classification
    }

    public func summarize(_ memory: Memory) async throws -> String { summary }
    public func extractTasks(from memory: Memory) async throws -> [MemoryTask] { tasks }
    public func embed(_ text: String) async throws -> [Float] { embedding }
}

public extension ClassificationResult {
    static let preview = ClassificationResult(
        kind: .text,
        category: "note",
        suggestedTags: ["sample"],
        priority: .normal,
        summary: "A sample summary.",
        extractedDates: [],
        extractedPeople: [],
        extractedLocations: []
    )
}
