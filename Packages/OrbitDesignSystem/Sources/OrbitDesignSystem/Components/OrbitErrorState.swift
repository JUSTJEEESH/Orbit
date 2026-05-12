import SwiftUI

/// Shared error-surface for view models in a `.failed` state. Visually
/// distinct from `OrbitEmptyState` — uses a warning-tinted glyph and
/// slightly tighter scale — so empty (a normal first-launch moment)
/// never gets confused with broken (something went wrong).
public struct OrbitErrorState: View {
    let systemImage: String
    let title: String
    let message: String?
    let onRetry: (@MainActor @Sendable () -> Void)?

    @Environment(\.orbitTheme) private var theme

    public init(
        systemImage: String = "exclamationmark.triangle.fill",
        title: String,
        message: String? = nil,
        onRetry: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: OrbitSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(OrbitColor.warning)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, OrbitSpacing.xs)
                .accessibilityHidden(true)
            Text(title)
                .font(OrbitTypography.title3)
                .foregroundStyle(OrbitColor.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onRetry {
                Button(action: { onRetry() }) {
                    Text("Try again")
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
