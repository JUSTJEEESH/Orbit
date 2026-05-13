import Foundation

/// The user-visible result of asking Orbit a question. Combines a short
/// narrative (the answer in the user's voice, written by Foundation Models)
/// with the specific memories that grounded it. The view chips one row of
/// source-memory thumbnails beneath the narrative — premium answers always
/// show their work.
public struct AskOrbitAnswer: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let question: String
    public let narrative: String
    /// IDs of memories the answer cites, in the order the AI referenced
    /// them. Empty when no memories matched (handled by the UI as
    /// "I don't have anything about that yet").
    public let sourceMemoryIDs: [UUID]
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        question: String,
        narrative: String,
        sourceMemoryIDs: [UUID],
        generatedAt: Date
    ) {
        self.id = id
        self.question = question
        self.narrative = narrative
        self.sourceMemoryIDs = sourceMemoryIDs
        self.generatedAt = generatedAt
    }
}
