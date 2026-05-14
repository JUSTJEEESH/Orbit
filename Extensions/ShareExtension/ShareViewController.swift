import UIKit
import SwiftUI
import UniformTypeIdentifiers
import OrbitDesignSystem
import OrbitDomain
import OrbitMedia
import OrbitPersistence

/// Premium share-sheet entry point. Replaces the previous
/// SLComposeServiceViewController-based implementation with a UIKit
/// host that presents a SwiftUI sheet (`ShareSheetView`) for full
/// design control.
///
/// Lifecycle:
///  1. iOS instantiates this VC when the user taps "Orbit" in any
///     share sheet (Safari, Photos, Notes, etc.)
///  2. `loadView` reads the inbound `NSExtensionItem` array, resolves
///     a `SharePayload` (URL + page title, plain text, or image with
///     thumbnail), and embeds the SwiftUI view in a host controller.
///  3. The user taps Save — the SwiftUI view calls back into our
///     `persist(...)` closure, which writes the memory to the App
///     Group SwiftData store via `CaptureMemoryUseCase`.
///  4. On success the view shows a brief "Saved ✓" state and we call
///     `extensionContext?.completeRequest`. On failure we surface an
///     inline error and let the user retry.
final class ShareViewController: UIViewController {

    private static let appGroupIdentifier = "group.com.joshgreen.orbit"

    /// Cached resolution of the inbound items so Save / Retry don't
    /// re-walk the NSItemProvider chain (which can be expensive for
    /// images that need a full data load).
    private var resolvedPayload: SharePayload?
    private var resolvedAttachments: [ResolvedAttachment] = []

    /// Internal representation of a fully-loaded attachment. Keeping
    /// this separate from `SharePayload` lets the preview-time payload
    /// stay UI-only (lightweight thumbnails) while the persistence
    /// path uses the full bytes.
    private enum ResolvedAttachment {
        case link(url: URL, title: String?)
        case text(String)
        case image(data: Data)
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.systemBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            await resolveInputs()
            presentSheet()
        }
    }

    // MARK: - Input resolution

    @MainActor
    private func resolveInputs() async {
        let inputs = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var attachments: [ResolvedAttachment] = []

        for item in inputs {
            for attachment in item.attachments ?? [] {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await loadURL(from: attachment) {
                        attachments.append(.link(url: url, title: item.attributedTitle?.string))
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = await loadImageData(from: attachment) {
                        attachments.append(.image(data: data))
                    }
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await loadText(from: attachment) {
                        attachments.append(.text(text))
                    }
                }
            }
        }

        resolvedAttachments = attachments
        resolvedPayload = makePayload(from: attachments)
    }

    /// Picks the most-specific attachment to preview. URL beats text
    /// (a Safari share carries both, and the URL is what the user
    /// expects to see). Image beats both when present.
    private func makePayload(from attachments: [ResolvedAttachment]) -> SharePayload {
        if let imageAttachment = attachments.first(where: { if case .image = $0 { return true } else { return false } }),
           case .image(let data) = imageAttachment {
            return SharePayload(kind: .image(thumbnail: UIImage(data: data)))
        }
        if let linkAttachment = attachments.first(where: { if case .link = $0 { return true } else { return false } }),
           case .link(let url, let title) = linkAttachment {
            return SharePayload(kind: .link(url: url, title: title))
        }
        if let textAttachment = attachments.first(where: { if case .text = $0 { return true } else { return false } }),
           case .text(let snippet) = textAttachment {
            return SharePayload(kind: .text(snippet: snippet))
        }
        return SharePayload(kind: .text(snippet: ""))
    }

    // MARK: - Sheet presentation

    @MainActor
    private func presentSheet() {
        // Fallback payload covers the (rare) case where no attachment
        // resolved — the sheet still renders so the user sees Cancel.
        let payload = resolvedPayload ?? SharePayload(kind: .text(snippet: ""))

        let sheet = ShareSheetView(
            payload: payload,
            onSave: { [weak self] note in
                guard let self else { return .failure(ShareSaveError.cancelled) }
                return await self.persist(note: note)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            },
            onCompleted: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        )

        let host = UIHostingController(rootView: sheet)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    // MARK: - Persistence

    @MainActor
    private func persist(note: String) async -> Result<Void, Error> {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let container = try ModelContainerFactory.makeContainer(
                mode: .appGroup(identifier: Self.appGroupIdentifier)
            )
            let repo = SwiftDataMemoryRepository(modelContainer: container)
            let storage = try MediaStorage.sharedAcrossExtensions(
                appGroupIdentifier: Self.appGroupIdentifier
            )
            let capture = CaptureMemoryUseCase(repository: repo, clock: SystemClock())

            let (content, media) = try await composeContent(
                note: trimmedNote,
                attachments: resolvedAttachments,
                storage: storage
            )
            _ = try await capture(content: content, media: media)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Builds the `MemoryContent` + `[MediaAsset]` pair the use case
    /// expects. Image attachments go through `MediaStorage.write` so
    /// the bytes land in the App Group container — which means the
    /// host app sees them on next foreground without an extra copy.
    private func composeContent(
        note: String,
        attachments: [ResolvedAttachment],
        storage: MediaStorage
    ) async throws -> (MemoryContent, [MediaAsset]) {
        // Image takes priority — if the user shared a photo with a
        // typed note, the result is an image memory with the note as
        // the caption.
        for attachment in attachments {
            if case .image(let data) = attachment {
                let stored = try await storage.write(data, kind: .image)
                let asset = MediaAsset(
                    kind: .image,
                    filename: stored.filename,
                    byteSize: stored.byteSize,
                    createdAt: Date()
                )
                let caption = note.isEmpty ? nil : note
                return (.image(caption: caption), [asset])
            }
        }
        // URL beats text (a Safari share carries both — the URL is the
        // user's intent; the text is just the page title or selection).
        for attachment in attachments {
            if case .link(let url, let title) = attachment {
                return (.link(url: url, title: note.isEmpty ? title : note, summary: nil), [])
            }
        }
        for attachment in attachments {
            if case .text(let shared) = attachment {
                let combined = note.isEmpty
                    ? shared
                    : "\(note)\n\n\(shared)"
                return (.text(combined), [])
            }
        }
        // No attachment resolved — fall back to the typed note alone
        // (still better than dropping the user's input).
        return (.text(note), [])
    }

    // MARK: - NSItemProvider helpers

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

    /// Returns JPEG-encoded bytes for the shared image. We deliberately
    /// re-encode to JPEG (~0.85 quality) rather than preserving the
    /// source format — keeps the App Group footprint reasonable for
    /// HEIC sources and matches `MediaStorage.Kind.image` which uses
    /// `.jpg` as its file extension.
    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                let data: Data? = {
                    if let url = item as? URL,
                       let raw = try? Data(contentsOf: url),
                       let image = UIImage(data: raw) {
                        return image.jpegData(compressionQuality: 0.85)
                    }
                    if let image = item as? UIImage {
                        return image.jpegData(compressionQuality: 0.85)
                    }
                    if let raw = item as? Data, let image = UIImage(data: raw) {
                        return image.jpegData(compressionQuality: 0.85)
                    }
                    return nil
                }()
                continuation.resume(returning: data)
            }
        }
    }
}

private enum ShareSaveError: Error {
    case cancelled
}
