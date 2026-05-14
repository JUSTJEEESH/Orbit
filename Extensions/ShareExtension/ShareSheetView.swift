import SwiftUI
import UIKit
import OrbitDesignSystem
import OrbitKit
import OrbitDomain

/// The premium share-sheet UI Orbit presents when the user shares to it
/// from Safari, Photos, Notes, or any other source. Hosted inside
/// `ShareViewController` via UIHostingController.
///
/// State machine (`SaveState`) keeps the UI honest about what's
/// happening — the previous SLComposeServiceViewController-based
/// version showed nothing on save and silently swallowed errors. Here:
/// idle → saving (spinner) → success (haptic + auto-dismiss) or
/// failed (inline error + Retry).
struct ShareSheetView: View {
    /// Snapshot of what the user is about to save. Resolved by the host
    /// view controller before this view renders so the SwiftUI body
    /// stays sync.
    let payload: SharePayload
    /// Async closure the host wires to the persistence path. Returns a
    /// Result so the view can drive the state machine; throws are
    /// treated identically to a `.failure` return (the host wraps).
    let onSave: @MainActor (_ note: String) async -> Result<Void, Error>
    let onCancel: @MainActor () -> Void
    /// Called after a successful save once the brief success state has
    /// rendered (~600ms). Host extension uses this to call
    /// `extensionContext.completeRequest`.
    let onCompleted: @MainActor () -> Void

    @State private var note: String = ""
    @State private var saveState: SaveState = .idle

    private enum SaveState: Equatable {
        case idle
        case saving
        case success
        case failed(message: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
                    previewCard
                    typeLabel
                    if saveState != .success {
                        noteField
                    }
                    if case .failed(let message) = saveState {
                        errorBanner(message: message)
                    }
                }
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
                .padding(.top, OrbitSpacing.lg)
                .padding(.bottom, OrbitSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .background(OrbitColor.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: OrbitSpacing.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(OrbitColor.accent)
                    .frame(width: 6, height: 6)
                Text("SAVE TO ORBIT")
                    .font(OrbitTypography.caption)
                    .tracking(0.9)
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            Spacer()
            Button("Cancel") {
                Haptics.play(.tap)
                onCancel()
            }
            .font(OrbitTypography.body)
            .foregroundStyle(OrbitColor.textSecondary)
            .disabled(saveState == .saving || saveState == .success)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .padding(.top, OrbitSpacing.md)
        .padding(.bottom, OrbitSpacing.sm)
    }

    // MARK: - Preview card

    @ViewBuilder
    private var previewCard: some View {
        OrbitCard(elevation: .resting) {
            switch payload.kind {
            case .link(let url, let title):
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundStyle(OrbitColor.textTertiary)
                        Text(url.host ?? url.absoluteString)
                            .font(OrbitTypography.caption)
                            .foregroundStyle(OrbitColor.textTertiary)
                            .lineLimit(1)
                    }
                    Text(title ?? url.absoluteString)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .text(let snippet):
                Text(snippet)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            case .image(let thumbnail):
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 220)
                            .clipShape(.rect(cornerRadius: OrbitRadius.sm))
                    } else {
                        // Image bytes loaded but couldn't decode — falls
                        // back to a quiet placeholder so the user still
                        // sees confirmation that something will save.
                        HStack(spacing: OrbitSpacing.sm) {
                            Image(systemName: "photo")
                                .scaledFont(size: 22, weight: .regular)
                                .foregroundStyle(OrbitColor.textTertiary)
                            Text("Photo")
                                .font(OrbitTypography.body)
                                .foregroundStyle(OrbitColor.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Type label ("Orbit will save this as a Link memory")

    private var typeLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: payload.kind.systemImage)
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(OrbitColor.textTertiary)
            Text("Orbit will save this as a \(payload.kind.label) memory.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Note field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
            Text("Add a note")
                .font(OrbitTypography.caption)
                .tracking(0.9)
                .foregroundStyle(OrbitColor.textTertiary)
            TextField("Optional", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textPrimary)
                .padding(OrbitSpacing.md)
                .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: OrbitRadius.md)
                        .stroke(OrbitColor.separator, lineWidth: 0.5)
                )
                .disabled(saveState == .saving || saveState == .success)
        }
    }

    // MARK: - Error banner

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: OrbitSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(OrbitColor.warning)
            Text(message)
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OrbitSpacing.md)
        .background(OrbitColor.warning.opacity(0.10), in: .rect(cornerRadius: OrbitRadius.md))
    }

    // MARK: - Footer (Save button)

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().background(OrbitColor.separator)
            ZStack {
                OrbitButton(
                    saveButtonTitle,
                    style: .primary,
                    size: .large
                ) {
                    Task { await save() }
                }
                .disabled(saveState == .saving || saveState == .success)
                if saveState == .saving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(OrbitColor.textInverted)
                }
            }
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            .padding(.vertical, OrbitSpacing.md)
        }
        .background(OrbitColor.background)
    }

    private var saveButtonTitle: String {
        switch saveState {
        case .idle, .saving: return "Save to Orbit"
        case .success:       return "Saved ✓"
        case .failed:        return "Try again"
        }
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        Haptics.play(.tap)
        saveState = .saving
        let result = await onSave(note)
        switch result {
        case .success:
            saveState = .success
            Haptics.play(.success)
            // Brief pause so the user sees the "Saved ✓" state before
            // the system sheet dismisses. ~600ms feels deliberate
            // without dragging.
            try? await Task.sleep(for: .milliseconds(600))
            onCompleted()
        case .failure(let error):
            saveState = .failed(message: friendlyMessage(for: error))
            Haptics.play(.warning)
        }
    }

    /// User-facing copy for save errors. Generic enough to cover the
    /// common cases (App Group not provisioned, disk full, container
    /// open failure) without exposing internal error types.
    private func friendlyMessage(for error: Error) -> String {
        "Couldn't save to Orbit. Open the app to retry, or try sharing again."
    }
}

// MARK: - SharePayload

/// What's about to be saved. Resolved by `ShareViewController` from the
/// `NSExtensionItem` array before the SwiftUI view renders. Carries
/// just enough for the preview to display — not the persistence shape.
struct SharePayload: Sendable {
    let kind: Kind

    enum Kind: Sendable {
        case link(url: URL, title: String?)
        case text(snippet: String)
        case image(thumbnail: UIImage?)
    }
}

extension SharePayload.Kind {
    /// Single-word noun used in the "Orbit will save this as a __ memory."
    /// label. Keep lowercase — the surrounding sentence supplies the case.
    var label: String {
        switch self {
        case .link:  return "Link"
        case .text:  return "Note"
        case .image: return "Photo"
        }
    }

    var systemImage: String {
        switch self {
        case .link:  return "link"
        case .text:  return "text.alignleft"
        case .image: return "photo"
        }
    }
}
