import Foundation

/// Asks the AI service to write a one-sentence "why these connect"
/// explanation for each related memory, given an anchor. Used by the
/// Connected section on Memory Detail to give each card a subtle subhead.
///
/// Returns an empty dictionary when the model can't land an honest
/// reason — the UI then renders the cards without subheads, which is
/// preferable to inventing a connection.
public struct ExplainConnectionsUseCase: Sendable {
    private let memories: any MemoryRepository
    private let ai: any AIService

    public init(memories: any MemoryRepository, ai: any AIService) {
        self.memories = memories
        self.ai = ai
    }

    public func callAsFunction(
        anchorID: UUID,
        relatedIDs: [UUID]
    ) async throws -> [UUID: String] {
        guard !relatedIDs.isEmpty else { return [:] }
        guard let anchor = try await memories.memory(with: anchorID) else { return [:] }

        // Resolve related IDs to Memory objects, preserving caller order
        // (the engine ranked them — keep the order so card 1 gets reason 1).
        var related: [Memory] = []
        for id in relatedIDs {
            if let memory = try await memories.memory(with: id) {
                related.append(memory)
            }
        }
        guard !related.isEmpty else { return [:] }

        return try await ai.explainConnections(anchor: anchor, related: related)
    }
}
