import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// "Your data" — where users get things back (Recently Deleted) and take
/// everything with them (Export).
struct SettingsDataSection: View {
    let accent: Color
    let onOpenRecentlyDeleted: @MainActor () -> Void
    /// Builds the export archive and returns its file URL.
    let onExport: (@MainActor @Sendable () async throws -> URL)?

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Your data")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    Button(action: onOpenRecentlyDeleted) {
                        row(
                            title: "Recently Deleted",
                            detail: "Restore anything deleted in the last 30 days.",
                            systemImage: "trash",
                            trailing: "chevron.right"
                        )
                    }
                    .buttonStyle(.plain)

                    if onExport != nil {
                        OrbitDivider()
                        exportRow
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exportRow: some View {
        if let exportURL {
            ShareLink(item: exportURL) {
                row(
                    title: "Share Your Export",
                    detail: "A journal, a data file, and every photo and recording.",
                    systemImage: "square.and.arrow.up",
                    trailing: nil
                )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: export) {
                row(
                    title: isExporting ? "Preparing Export…" : "Export Everything",
                    detail: exportFailed
                        ? "Couldn’t create the export. Please try again."
                        : "Keep a copy of all your memories in open formats.",
                    systemImage: "doc.zipper",
                    trailing: nil,
                    isError: exportFailed,
                    showsProgress: isExporting
                )
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
    }

    private func row(
        title: String,
        detail: String,
        systemImage: String,
        trailing: String?,
        isError: Bool = false,
        showsProgress: Bool = false
    ) -> some View {
        HStack(spacing: OrbitSpacing.sm) {
            Image(systemName: systemImage)
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(accent)
                .frame(width: OrbitSpacing.xl)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                Text(title)
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(detail)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(isError ? OrbitColor.danger : OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if showsProgress {
                ProgressView()
            } else if let trailing {
                Image(systemName: trailing)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(OrbitColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, OrbitSpacing.xs)
        .contentShape(Rectangle())
    }

    private func export() {
        guard let onExport else { return }
        isExporting = true
        exportFailed = false
        Task {
            do {
                exportURL = try await onExport()
                Haptics.play(.success)
            } catch {
                exportFailed = true
                Haptics.play(.failure)
            }
            isExporting = false
        }
    }
}
