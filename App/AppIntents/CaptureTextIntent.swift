import AppIntents
import OrbitDomain
import OrbitPersistence
import OrbitKit

/// "Capture to Orbit" — invokable from Shortcuts, Siri, the Action Button,
/// or anywhere `AppIntent` is surfaced. Spins up a short-lived SwiftData
/// container so capture works without the app having to be in the
/// foreground.
///
/// The container must be the App Group store — the one the app, widgets and
/// Share Extension read. Orbit 1.x opened the per-app `.onDisk` store here,
/// so Siri captures were saved where nothing ever displayed them; 2.0's
/// `LegacyStoreRescue` recovers those. Enrichment for intent captures runs
/// in the app's launch maintenance pass.
struct CaptureTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture to Orbit"
    static let description = IntentDescription(
        "Save a thought, note, or reminder into your Orbit memory.",
        categoryName: "Capture"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Text",
        description: "What you want Orbit to remember.",
        inputOptions: String.IntentInputOptions(
            keyboardType: .default,
            capitalizationType: .sentences,
            multiline: true
        )
    )
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "I need something to remember.")
        }

        do {
            let appGroup = AppConfig.resolveFromBundle().appGroupIdentifier
            let container = try ModelContainerFactory.makeContainer(mode: .appGroup(identifier: appGroup))
            let repository = SwiftDataMemoryRepository(modelContainer: container)
            let capture = CaptureMemoryUseCase(repository: repository, clock: SystemClock())
            _ = try await capture(content: .text(trimmed))
            OrbitLog.capture.notice("AppIntent captured a text memory.")
            return .result(dialog: "Saved to Orbit.")
        } catch {
            OrbitLog.capture.error("AppIntent failed: \(String(describing: error), privacy: .public)")
            return .result(dialog: "Orbit couldn't save that — try again from the app.")
        }
    }
}
