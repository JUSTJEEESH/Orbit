import SwiftUI
import OrbitDesignSystem
import OrbitKit
import OrbitPersistence
import os

/// Shown instead of the app when the memory library can't be opened.
///
/// Orbit 1.x silently swapped in a temporary in-memory store here, so users
/// saw an empty app and anything they captured vanished on quit. This screen
/// replaces that: it says plainly that nothing was deleted, never writes to
/// a stand-in store, and offers three ways forward — retry, export a raw
/// copy of the library, or contact support.
struct StoreRecoveryView: View {
    let appGroupIdentifier: String
    let errorDescription: String
    let onRetry: @MainActor () -> Void

    @State private var isArchiving = false
    @State private var archiveURL: URL?
    @State private var archiveFailed = false
    @State private var showsDetails = false

    private enum Links {
        static let support = URL(string: "https://orbitbrain2.netlify.app/support")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                header
                actions
                details
            }
            .padding(.horizontal, OrbitSpacing.xl)
            .padding(.vertical, OrbitSpacing.xxxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(OrbitColor.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Image(systemName: "lock.shield")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            Text("Your memories are safe")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Orbit couldn’t open your library just now. Nothing has been deleted — everything is still stored on this iPhone.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: OrbitSpacing.sm) {
            OrbitButton("Try Again", systemImage: "arrow.clockwise", style: .primary, size: .large) {
                onRetry()
            }

            if let archiveURL {
                ShareLink(item: archiveURL) {
                    Label("Save the Copy", systemImage: "square.and.arrow.up")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: OrbitHitTarget.minimum + OrbitSpacing.xxs)
                        .background(OrbitColor.surfaceMuted, in: .rect(cornerRadius: OrbitRadius.md))
                }
            } else {
                OrbitButton(
                    isArchiving ? "Preparing a Copy…" : "Export a Copy",
                    systemImage: "doc.zipper",
                    style: .secondary
                ) {
                    makeArchive()
                }
                .disabled(isArchiving)
            }

            if archiveFailed {
                Text("Couldn’t prepare a copy. Your library is untouched — please contact support.")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let support = Links.support {
                Link(destination: support) {
                    Text("Contact Support")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: OrbitHitTarget.minimum)
                }
            }
        }
    }

    private var details: some View {
        DisclosureGroup(isExpanded: $showsDetails) {
            Text(errorDescription)
                .font(OrbitTypography.footnote.monospaced())
                .foregroundStyle(OrbitColor.textSecondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, OrbitSpacing.xs)
        } label: {
            Text("Technical details")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textTertiary)
        }
        .tint(OrbitColor.textTertiary)
    }

    private func makeArchive() {
        isArchiving = true
        archiveFailed = false
        let identifier = appGroupIdentifier
        Task {
            // File copying can take a moment for large media libraries, so
            // it runs off the main actor.
            let result = await Task.detached(priority: .userInitiated) {
                Result { try LibraryArchiver.makeArchive(appGroupIdentifier: identifier) }
            }.value
            isArchiving = false
            switch result {
            case .success(let url):
                archiveURL = url
                Haptics.play(.success)
            case .failure(let error):
                archiveFailed = true
                OrbitLog.persistence.error("Library archive failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

#Preview {
    StoreRecoveryView(
        appGroupIdentifier: "group.com.joshgreen.orbit",
        errorDescription: "SwiftDataError(_error: .loadIssueModelContainer)",
        onRetry: {}
    )
}
