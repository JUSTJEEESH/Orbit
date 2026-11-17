import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitAI
import UIKit

/// Recent screenshots, each with what Orbit thinks it is. Save keeps it as
/// a searchable memory (plus a reminder if it's dated); Skip leaves it alone.
struct ScreenshotInboxView: View {
    let inbox: ScreenshotInbox
    let onDone: @MainActor () -> Void

    @State private var savingID: String?
    @State private var failedID: String?

    var body: some View {
        NavigationStack {
            Group {
                if inbox.pending.isEmpty {
                    OrbitEmptyState(
                        systemImage: "rectangle.on.rectangle",
                        title: inbox.isScanning ? "Looking at your screenshots…" : "All sorted",
                        message: inbox.isScanning ? nil : "New screenshots will show up here, ready to keep."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: OrbitSpacing.md) {
                            ForEach(inbox.pending) { candidate in
                                card(candidate)
                                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            }
                        }
                        .padding(.horizontal, OrbitSpacing.pageHorizontal)
                        .padding(.vertical, OrbitSpacing.lg)
                        .animation(OrbitMotion.smooth, value: inbox.pending)
                    }
                }
            }
            .background(OrbitColor.background)
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
            }
            .task { await inbox.scan() }
        }
    }

    private func card(_ candidate: ScreenshotInbox.Candidate) -> some View {
        OrbitCard {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                HStack(alignment: .top, spacing: OrbitSpacing.md) {
                    if let image = UIImage(data: candidate.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 96)
                            .clipShape(.rect(cornerRadius: OrbitRadius.sm))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Label(kindLabel(candidate.suggestion.kind), systemImage: kindSymbol(candidate.suggestion.kind))
                            .font(OrbitTypography.caption)
                            .foregroundStyle(OrbitColor.textSecondary)
                        Text(candidate.suggestion.title ?? "Screenshot")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                            .lineLimit(2)
                        Text(candidate.text)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .lineLimit(3)
                    }
                }
                if failedID == candidate.id {
                    Text("Couldn’t save that one. Try again.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.danger)
                }
                HStack(spacing: OrbitSpacing.sm) {
                    OrbitButton("Skip", style: .secondary) {
                        inbox.skip(candidate)
                    }
                    OrbitButton(savingID == candidate.id ? "Saving…" : saveTitle(candidate.suggestion.kind), style: .primary) {
                        save(candidate)
                    }
                    .disabled(savingID != nil)
                }
            }
        }
    }

    private func save(_ candidate: ScreenshotInbox.Candidate) {
        savingID = candidate.id
        failedID = nil
        Task {
            do {
                try await inbox.save(candidate)
                Haptics.play(.success)
            } catch {
                failedID = candidate.id
                Haptics.play(.failure)
            }
            savingID = nil
        }
    }

    private func kindLabel(_ kind: ScreenshotClassifier.Kind) -> String {
        switch kind {
        case .event(let date): "Event · \(date.formatted(date: .abbreviated, time: .shortened))"
        case .receipt:         "Receipt"
        case .recipe:          "Recipe"
        case .note:            "Note"
        }
    }

    private func kindSymbol(_ kind: ScreenshotClassifier.Kind) -> String {
        switch kind {
        case .event:   "calendar"
        case .receipt: "receipt"
        case .recipe:  "fork.knife"
        case .note:    "text.alignleft"
        }
    }

    private func saveTitle(_ kind: ScreenshotClassifier.Kind) -> String {
        if case .event = kind { return "Keep + Remind" }
        return "Keep"
    }
}
