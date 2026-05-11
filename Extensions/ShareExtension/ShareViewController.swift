import UIKit
import Social
import UniformTypeIdentifiers
import OrbitDomain
import OrbitPersistence

/// Lightweight share-sheet handler. Uses `SLComposeServiceViewController` so
/// we get the standard preview-and-comment chrome; user text from the
/// compose field is combined with the shared item before saving.
final class ShareViewController: SLComposeServiceViewController {

    private static let appGroupIdentifier = "group.com.orbit.app"

    override func isContentValid() -> Bool {
        // Allow posting with either user-typed text or at least one
        // attachment from the source app.
        if let text = contentText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return !(extensionContext?.inputItems.isEmpty ?? true)
    }

    override func didSelectPost() {
        let typed = contentText ?? ""
        let inputs = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        Task {
            await persist(typedText: typed, inputItems: inputs)
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! { [] }

    // MARK: - Persistence

    @MainActor
    private func persist(typedText: String, inputItems: [NSExtensionItem]) async {
        let content = await composeContent(typedText: typedText, inputItems: inputItems)

        do {
            let container = try ModelContainerFactory.makeContainer(
                mode: .appGroup(identifier: Self.appGroupIdentifier)
            )
            let repo = SwiftDataMemoryRepository(modelContainer: container)
            let capture = CaptureMemoryUseCase(repository: repo, clock: SystemClock())
            _ = try await capture(content: content)
        } catch {
            // Best-effort — if persistence fails we let the user know via
            // the system's "couldn't share" toast by completing with
            // cancellation. For Phase 6 we accept silent failure; the user
            // can retry from inside the app.
        }
    }

    private func composeContent(
        typedText: String,
        inputItems: [NSExtensionItem]
    ) async -> MemoryContent {
        let trimmedTyped = typedText.trimmingCharacters(in: .whitespacesAndNewlines)

        for item in inputItems {
            for attachment in item.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await loadURL(from: attachment) {
                        return .link(
                            url: url,
                            title: trimmedTyped.isEmpty ? item.attributedTitle?.string : trimmedTyped,
                            summary: nil
                        )
                    }
                }
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let shared = await loadText(from: attachment) {
                        let combined = trimmedTyped.isEmpty
                            ? shared
                            : "\(trimmedTyped)\n\n\(shared)"
                        return .text(combined)
                    }
                }
            }
        }

        return .text(trimmedTyped)
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
