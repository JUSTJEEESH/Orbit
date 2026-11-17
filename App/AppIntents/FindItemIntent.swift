import AppIntents
import OrbitDomain
import OrbitPersistence
import OrbitKit
import os

/// "Where did I put…" from Siri or Shortcuts: answers from the user's own
/// notes ("Your passport is in the blue box, top shelf.") without opening
/// the app. Opens the same App Group store as `CaptureTextIntent`.
struct FindItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Something in Orbit"
    static let description = IntentDescription(
        "Ask where you put something, answered from your Orbit memories.",
        categoryName: "Recall"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Item",
        description: "What you're looking for, like \u{201C}passport\u{201D}.",
        requestValueDialog: IntentDialog("What are you looking for?")
    )
    var item: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Tell me what you're looking for.")
        }
        do {
            let appGroup = AppConfig.resolveFromBundle().appGroupIdentifier
            let container = try ModelContainerFactory.makeContainer(mode: .appGroup(identifier: appGroup))
            let repository = SwiftDataMemoryRepository(modelContainer: container)
            // Accepts "passport" or a full "where's my passport".
            let find = FindPlacementUseCase(memories: repository)
            var found = try await find(question: trimmed)
            if found == nil {
                found = try await find(item: trimmed)
            }
            guard let found else {
                return .result(dialog: "I couldn't find where you put that. Next time, tell Orbit where it goes and I'll remember.")
            }
            let sentence = found.placement.sentence
            return .result(dialog: "\(sentence)")
        } catch {
            OrbitLog.app.error("FindItemIntent failed: \(String(describing: error), privacy: .public)")
            return .result(dialog: "Orbit couldn't look that up right now. Try again from the app.")
        }
    }
}
