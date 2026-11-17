import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// What Home needs to offer the "Add a widget" card.
public struct HomeWidgetNudge {
    public let onShowHow: @MainActor () -> Void
    public let onDismiss: @MainActor () -> Void

    public init(onShowHow: @escaping @MainActor () -> Void, onDismiss: @escaping @MainActor () -> Void) {
        self.onShowHow = onShowHow
        self.onDismiss = onDismiss
    }
}

/// A one-time suggestion to add Orbit's widget. People who keep Orbit on
/// their Home Screen capture more and come back more, so the card appears
/// once they've captured a few memories and have no Orbit widget yet, and
/// never again once dismissed.
struct WidgetNudgeCard: View {
    let nudge: HomeWidgetNudge
    let accent: Color

    var body: some View {
        OrbitCard {
            HStack(alignment: .top, spacing: OrbitSpacing.md) {
                Image(systemName: "square.grid.2x2")
                    .font(OrbitTypography.title2)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    Text("Put Orbit on your Home Screen")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Capture in one tap, and see a memory worth revisiting every time you unlock.")
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Haptics.play(.tap)
                        nudge.onShowHow()
                    } label: {
                        Text("Show Me How")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(accent)
                            .frame(minHeight: OrbitHitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.play(.selection)
                    nudge.onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .frame(width: OrbitHitTarget.minimum, height: OrbitHitTarget.minimum)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss widget suggestion")
            }
        }
    }
}

/// What Home needs to show the Screenshot Inbox card.
public struct HomeScreenshotNudge {
    public let count: Int
    public let onOpen: @MainActor () -> Void

    public init(count: Int, onOpen: @escaping @MainActor () -> Void) {
        self.count = count
        self.onOpen = onOpen
    }
}

/// "3 new screenshots to sort" — opens the Screenshot Inbox.
struct ScreenshotNudgeCard: View {
    let nudge: HomeScreenshotNudge
    let accent: Color

    var body: some View {
        Button {
            Haptics.play(.tap)
            nudge.onOpen()
        } label: {
            OrbitCard {
                HStack(spacing: OrbitSpacing.md) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(OrbitTypography.title3)
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text(nudge.count == 1 ? "1 new screenshot to sort" : "\(nudge.count) new screenshots to sort")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                            .contentTransition(.numericText(value: Double(nudge.count)))
                        Text("Keep what matters, with reminders for anything dated.")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
