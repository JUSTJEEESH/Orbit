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

    public func dailyRecap(memories: [Memory], date: Date) async throws -> DailyRecapDraft {
        // Build a compact transcript so we don't blow the model's context.
        // Order chronologically so the recap has a sense of arc.
        let lines = memories
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(60)
            .map { Self.recapLine(for: $0) }
        let bullets = lines.joined(separator: "\n")

        // No model? Hand back something pleasant and serviceable.
        if case .unavailable = SystemLanguageModel.default.availability {
            return Self.heuristicRecap(memories: memories, bullets: bullets)
        }

        do {
            let session = LanguageModelSession(instructions: Self.recapInstructions)
            let response = try await session.respond(
                to: Self.recapPrompt(for: date, bullets: bullets),
                generating: GeneratedDailyRecap.self
            )
            let generated = response.content
            let highlightIDs = Self.matchHighlights(
                titles: generated.highlights,
                memories: memories
            )
            return DailyRecapDraft(
                narrative: generated.narrative.trimmingCharacters(in: .whitespacesAndNewlines),
                mood: generated.mood.trimmedNonEmpty?.lowercased(),
                highlightIDs: highlightIDs
            )
        } catch {
            return Self.heuristicRecap(memories: memories, bullets: bullets)
        }
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

    // MARK: - Daily recap

    private static let recapInstructions = """
    You are Orbit, a calm second brain. Reflect the user's day back to \
    them in 2-3 sentences of warm, second-person prose — like a thoughtful \
    journal entry. Do not invent facts. Pick a one-word lowercase mood \
    that fits the day (e.g. focused, scattered, calm, productive, \
    reflective, restless, grateful) and surface up to three short titles \
    that summarize the most notable moments.
    """

    private static func recapPrompt(for date: Date, bullets: String) -> String {
        let dayLabel = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return """
        Day: \(dayLabel)
        Captures (chronological):
        \"\"\"
        \(bullets)
        \"\"\"

        Write the recap.
        """
    }

    private static func recapLine(for memory: Memory) -> String {
        let timeLabel = memory.createdAt.formatted(date: .omitted, time: .shortened)
        let body: String = {
            switch memory.content {
            case .text(let s):                                   return s
            case .voiceNote(let transcript, _):                  return transcript ?? "[voice note]"
            case .image(let caption):                            return caption ?? "[photo]"
            case .link(let url, let title, let summary):
                return [title, summary, url.absoluteString].compactMap { $0 }.first ?? url.absoluteString
            case .screenshot(let ocr):                           return ocr ?? "[screenshot]"
            case .location(let name, _, _):                      return name ?? "[place]"
            }
        }()
        return "- \(timeLabel) — \(String(body.prefix(140)))"
    }

    /// Looks for memories whose headline contains any AI-suggested
    /// highlight title. Falls back to the first three captures so the
    /// view always has at least something to show.
    private static func matchHighlights(titles: [String], memories: [Memory]) -> [UUID] {
        guard !titles.isEmpty else { return [] }
        var matched: [UUID] = []
        for title in titles.prefix(5) {
            let needle = title.lowercased()
            guard let hit = memories.first(where: { Self.headline(for: $0).lowercased().contains(needle) }) else { continue }
            if !matched.contains(hit.id) { matched.append(hit.id) }
        }
        return matched
    }

    private static func headline(for memory: Memory) -> String {
        if let summary = memory.ai.summary, !summary.isEmpty { return summary }
        switch memory.content {
        case .text(let s):                                   return s
        case .voiceNote(let transcript, _):                  return transcript ?? "Voice note"
        case .image(let caption):                            return caption ?? "Photo"
        case .link(_, let title, let summary):               return summary ?? title ?? "Link"
        case .screenshot(let ocr):                           return ocr ?? "Screenshot"
        case .location(let name, _, _):                      return name ?? "Location"
        }
    }

    /// Composed recap when Apple Intelligence isn't available. Reads
    /// naturally enough that the experience doesn't feel broken on
    /// older devices — it just doesn't sing.
    private static func heuristicRecap(memories: [Memory], bullets: String) -> DailyRecapDraft {
        let count = memories.count
        let kinds = Set(memories.map(\.content.kind))
        let kindWords: [String] = kinds.compactMap { kind in
            switch kind {
            case .text:        return count > 0 ? "thoughts" : nil
            case .voiceNote:   return "voice notes"
            case .image:       return "photos"
            case .link:        return "links"
            case .screenshot:  return "screenshots"
            case .location:    return "places"
            }
        }
        let kindFragment: String = {
            switch kindWords.count {
            case 0: return "moments"
            case 1: return kindWords[0]
            case 2: return "\(kindWords[0]) and \(kindWords[1])"
            default:
                let head = kindWords.prefix(kindWords.count - 1).joined(separator: ", ")
                return "\(head), and \(kindWords.last!)"
            }
        }()
        let countWord = count == 1 ? "moment" : "moments"
        let narrative = "You captured \(count) \(countWord) today — a mix of \(kindFragment). Worth a glance."
        let highlights = Array(memories.prefix(3).map(\.id))
        return DailyRecapDraft(narrative: narrative, mood: nil, highlightIDs: highlights)
    }
}

@Generable
struct GeneratedDailyRecap {
    @Guide(description: "2-3 sentences of warm, second-person prose reflecting the user's day. No bullet points.")
    let narrative: String

    @Guide(description: "One lowercase word that captures the day's mood. Empty string if unclear.")
    let mood: String

    @Guide(description: "Up to three short headline-style strings that summarize the day's most notable captures.")
    let highlights: [String]
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
