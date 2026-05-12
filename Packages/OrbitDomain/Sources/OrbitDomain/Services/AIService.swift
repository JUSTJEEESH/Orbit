import Foundation

/// The AI surface area used by feature code. The default implementation in
/// Phase 3 routes to Apple Foundation Models on-device; a fallback adapter
/// proxies to a remote model via an edge function.
public protocol AIService: Sendable {
    func classify(_ raw: RawCapture) async throws -> ClassificationResult
    func summarize(_ memory: Memory) async throws -> String
    func extractTasks(from memory: Memory) async throws -> [MemoryTask]
    func embed(_ text: String) async throws -> [Float]
    func dailyRecap(memories: [Memory], date: Date) async throws -> DailyRecapDraft
    /// Answers a natural-language question using the supplied memories as
    /// the only source of truth. The returned draft must cite memories by
    /// their *index* in the input array — the use case resolves those to
    /// actual `Memory.id` values for the UI.
    func askOrbit(question: String, memories: [Memory]) async throws -> AskOrbitDraft
}

/// AI-side payload for `AskOrbit`. The use case stamps `generatedAt`,
/// resolves citation indices into memory IDs, and wraps everything into
/// the final domain answer.
public struct AskOrbitDraft: Sendable, Equatable {
    public let narrative: String
    /// Indices into the `memories` array that the answer cites. Out-of-
    /// bounds indices are silently dropped at the use-case layer.
    public let citationIndices: [Int]

    public init(narrative: String, citationIndices: [Int]) {
        self.narrative = narrative
        self.citationIndices = citationIndices
    }
}

/// AI-side payload for `DailyRecap`. The use case is responsible for
/// stamping `generatedAt` and resolving highlight IDs into the final
/// domain entity, so the AI surface stays free of clock dependencies.
public struct DailyRecapDraft: Sendable, Equatable {
    public let narrative: String
    public let mood: String?
    public let highlightIDs: [UUID]

    public init(narrative: String, mood: String?, highlightIDs: [UUID]) {
        self.narrative = narrative
        self.mood = mood
        self.highlightIDs = highlightIDs
    }
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
