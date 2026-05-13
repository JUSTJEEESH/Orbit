import Foundation

/// Captures one gratitude session — typically three short entries the user
/// types in the dedicated surface. Stored as a single Memory so the streak
/// math is "one entry per day," the category is fixed to "gratitude" so the
/// Daily Recap + Insights can recognise it, and a system-origin tag is
/// attached for the smart-folder UI.
public struct CaptureGratitudeUseCase: Sendable {
    private let captureMemory: CaptureMemoryUseCase

    public init(captureMemory: CaptureMemoryUseCase) {
        self.captureMemory = captureMemory
    }

    @discardableResult
    public func callAsFunction(entries: [String]) async throws -> Memory? {
        let cleaned = entries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }

        // Format: numbered list, one entry per line. Keeps the eventual
        // memory body human-readable in Timeline / Search / Recap.
        let body = cleaned.enumerated()
            .map { (index, text) in "\(index + 1). \(text)" }
            .joined(separator: "\n")

        // `Tag.Origin.ai` is the non-user-typed origin we have today —
        // good enough to mark gratitude as system-generated alongside the
        // category tags the AI pipeline applies.
        return try await captureMemory(
            content: .text(body),
            tags: [Tag(name: GratitudeTag.name, origin: .ai)]
        )
    }
}
