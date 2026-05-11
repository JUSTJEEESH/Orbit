import Foundation
import FoundationModels
import OrbitDomain

/// `AIService` backed by Apple's on-device foundation model. All inference
/// happens locally — capture content never leaves the device. Falls back to
/// a non-LLM classification (entity extraction only) when the system model
/// is unavailable on this device or in this region.
public actor FoundationModelsAdapter: AIService {
    private let entities: EntityExtractor
    private let embeddings: EmbeddingService

    public init(
        entities: EntityExtractor = EntityExtractor(),
        embeddings: EmbeddingService = EmbeddingService()
    ) {
        self.entities = entities
        self.embeddings = embeddings
    }

    public func classify(_ raw: RawCapture) async throws -> ClassificationResult {
        let text = Self.compose(raw)
        let extracted = entities.extract(from: text)
        let kind: MemoryContentKind = raw.url != nil
            ? .link
            : (raw.audioTranscript != nil ? .voiceNote : (raw.imageData != nil ? .image : .text))

        guard !text.isEmpty else {
            return ClassificationResult(
                kind: kind,
                category: nil,
                suggestedTags: [],
                priority: .normal,
                summary: nil,
                extractedDates: extracted.dates,
                extractedPeople: extracted.people,
                extractedLocations: extracted.locations
            )
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable:
            // Apple Intelligence not yet ready on this device — degrade
            // gracefully. Heuristic category + entity extraction still
            // give the timeline meaningful color.
            return Self.fallbackResult(
                kind: kind,
                text: text,
                extracted: extracted
            )
        @unknown default:
            return Self.fallbackResult(
                kind: kind,
                text: text,
                extracted: extracted
            )
        }

        let session = LanguageModelSession(instructions: Self.systemInstructions)
        let prompt = Self.prompt(for: text)

        // If the model errors (token limit, guardrail, transient failure) we
        // still ship a usable result by falling back to the heuristic path.
        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedClassification.self
            )
            let generated = response.content

            // Backstop: if the LLM returned nothing useful, infer a
            // category heuristically so the eyebrow still has color.
            let category = generated.category.trimmedNonEmpty
                ?? HeuristicCategoryInferrer.infer(text: text, entities: extracted)

            return ClassificationResult(
                kind: kind,
                category: category,
                suggestedTags: Array(
                    generated.tags
                        .map(\.trimmedLowercased)
                        .filter { !$0.isEmpty }
                        .prefix(3)
                ),
                priority: MemoryAIMetadata.Priority(rawValue: max(0, min(3, generated.priority))) ?? .normal,
                summary: generated.summary.trimmedNonEmpty,
                extractedDates: extracted.dates,
                extractedPeople: extracted.people,
                extractedLocations: extracted.locations
            )
        } catch {
            return Self.fallbackResult(
                kind: kind,
                text: text,
                extracted: extracted
            )
        }
    }

    private static func fallbackResult(
        kind: MemoryContentKind,
        text: String,
        extracted: ExtractedEntities
    ) -> ClassificationResult {
        ClassificationResult(
            kind: kind,
            category: HeuristicCategoryInferrer.infer(text: text, entities: extracted),
            suggestedTags: [],
            priority: .normal,
            summary: heuristicSummary(text),
            extractedDates: extracted.dates,
            extractedPeople: extracted.people,
            extractedLocations: extracted.locations
        )
    }

    public func summarize(_ memory: Memory) async throws -> String {
        let raw = RawCapture(memory: memory)
        let result = try await classify(raw)
        return result.summary ?? Self.compose(raw)
    }

    public func extractTasks(from memory: Memory) async throws -> [MemoryTask] {
        // Phase 4 will use a dedicated tool-call prompt for this. For now,
        // return an empty list rather than over-promise.
        []
    }

    public func embed(_ text: String) async throws -> [Float] {
        let vector = await embeddings.embed(text)
        if vector.isEmpty { throw OrbitError.aiUnavailable }
        return vector
    }

    // MARK: - Prompting

    private static let systemInstructions = """
    You are Orbit, an on-device AI assistant that helps the user remember \
    things. For every capture, return a short summary (max 12 words), a \
    one-word category drawn from {idea, task, reminder, note, travel, work, \
    health, finance, social, learning, journal}, a priority (0=low, \
    1=normal, 2=high, 3=urgent), and up to 3 lowercase tags. Be concise, \
    never editorialize, and never invent facts.
    """

    private static func prompt(for text: String) -> String {
        let trimmed = String(text.prefix(2_000))
        return "Capture:\n\"\"\"\n\(trimmed)\n\"\"\""
    }

    private static func compose(_ raw: RawCapture) -> String {
        var parts: [String] = []
        if let text = raw.text, !text.isEmpty { parts.append(text) }
        if let transcript = raw.audioTranscript, !transcript.isEmpty { parts.append(transcript) }
        if let url = raw.url { parts.append(url.absoluteString) }
        return parts.joined(separator: "\n")
    }

    private static func heuristicSummary(_ text: String) -> String? {
        let first = text.split(separator: ".").first.map(String.init) ?? text
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 120 ? String(trimmed.prefix(117)) + "…" : trimmed
    }
}

@Generable
struct GeneratedClassification {
    @Guide(description: "One-sentence summary of the capture, max 12 words.")
    let summary: String

    @Guide(description: "One-word lowercase category like idea, task, reminder, note, travel, work, health, finance, social, learning, or journal.")
    let category: String

    @Guide(description: "Urgency from 0 (low) to 3 (urgent). Use 3 only if the user used words like asap, urgent, today.")
    let priority: Int

    @Guide(description: "Up to three short lowercase topic tags.")
    let tags: [String]
}

private extension String {
    var trimmedLowercased: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
