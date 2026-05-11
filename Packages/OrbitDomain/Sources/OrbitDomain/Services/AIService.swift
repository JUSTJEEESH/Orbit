import Foundation

/// The AI surface area used by feature code. The default implementation in
/// Phase 3 routes to Apple Foundation Models on-device; a fallback adapter
/// proxies to a remote model via an edge function.
public protocol AIService: Sendable {
    func classify(_ raw: RawCapture) async throws -> ClassificationResult
    func summarize(_ memory: Memory) async throws -> String
    func extractTasks(from memory: Memory) async throws -> [MemoryTask]
    func embed(_ text: String) async throws -> [Float]
}

public struct RawCapture: Sendable {
    public let text: String?
    public let url: URL?
    public let imageData: Data?
    public let audioTranscript: String?

    public init(
        text: String? = nil,
        url: URL? = nil,
        imageData: Data? = nil,
        audioTranscript: String? = nil
    ) {
        self.text = text
        self.url = url
        self.imageData = imageData
        self.audioTranscript = audioTranscript
    }
}

public struct ClassificationResult: Sendable {
    public let kind: MemoryContentKind
    public let category: String?
    public let suggestedTags: [String]
    public let priority: MemoryAIMetadata.Priority
    public let summary: String?
    public let extractedDates: [Date]
    public let extractedPeople: [String]
    public let extractedLocations: [String]

    public init(
        kind: MemoryContentKind,
        category: String?,
        suggestedTags: [String],
        priority: MemoryAIMetadata.Priority,
        summary: String?,
        extractedDates: [Date],
        extractedPeople: [String],
        extractedLocations: [String]
    ) {
        self.kind = kind
        self.category = category
        self.suggestedTags = suggestedTags
        self.priority = priority
        self.summary = summary
        self.extractedDates = extractedDates
        self.extractedPeople = extractedPeople
        self.extractedLocations = extractedLocations
    }
}
