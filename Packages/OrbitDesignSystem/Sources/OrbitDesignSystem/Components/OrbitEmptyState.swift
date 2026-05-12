import SwiftUI

/// Shared empty-state surface. The first paint a user sees in a tab,
/// section, or sheet before any data exists. Built as a single
/// premium-feeling unit — SF Symbol at the top, title, supporting
/// sentence, optional call-to-action — so every empty state in the
/// app sets the same calm, intentional tone.
///
/// Use the more specific copy your feature already had; this view
/// just gives it consistent typography, scale, and centering.
public struct OrbitEmptyState: View {
    public struct Action: Sendable {
        let title: String
        let onTap: @MainActor @Sendable () -> Void

        public init(title: String, onTap: @escaping @MainActor @Sendable () -> Void) {
            self.title = title
            self.onTap = onTap
        }
    }

    let systemImage: String?
    let title: String
    let message: String?
    let action: Action?

    @Environment(\.orbitTheme) private var theme

    public init(
        systemImage: String? = nil,
        title: String,
        message: String? = nil,
        action: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: OrbitSpacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(OrbitColor.textTertiary)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.bottom, OrbitSpacing.xs)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action {
                Button(action: { action.onTap() }) {
                    Text(action.title)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, OrbitSpacing.md)
                        .padding(.vertical, OrbitSpacing.xs)
                        .background(theme.primary.opacity(0.12), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, OrbitSpacing.sm)
            }
        }
        .padding(.horizontal, OrbitSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}
