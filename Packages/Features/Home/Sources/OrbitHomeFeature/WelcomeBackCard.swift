import SwiftUI
import OrbitDesignSystem
import OrbitDomain
import OrbitKit

/// What Home needs for the "Welcome back" card.
public struct HomeWelcomeBack {
    public let welcome: WelcomeBack
    public let onOpenTasks: @MainActor () -> Void
    public let onDismiss: @MainActor () -> Void

    public init(
        welcome: WelcomeBack,
        onOpenTasks: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.welcome = welcome
        self.onOpenTasks = onOpenTasks
        self.onDismiss = onDismiss
    }
}

/// After time away, a calm "here's what's still open" instead of guilt.
/// No streak, no count of missed days framed as failure: just how long it's
/// been, the few things worth a look, and permission to start anywhere.
struct WelcomeBackCard: View {
    let model: HomeWelcomeBack
    let accent: Color

    private var welcome: WelcomeBack { model.welcome }

    var body: some View {
        OrbitCard(elevation: .lifted) {
            VStack(alignment: .leading, spacing: OrbitSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
                        Text("Welcome back")
                            .font(OrbitTypography.title2)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text(message)
                            .font(OrbitTypography.callout)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: OrbitSpacing.sm)
                    Button {
                        Haptics.play(.selection)
                        model.onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textTertiary)
                            .frame(width: OrbitHitTarget.minimum, height: OrbitHitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }

                if !welcome.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                        ForEach(welcome.highlights) { task in
                            highlightRow(task)
                        }
                    }
                    Button {
                        Haptics.play(.tap)
                        model.onOpenTasks()
                    } label: {
                        Text(moreLabel)
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(accent)
                            .frame(minHeight: OrbitHitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var message: String {
        let gap = welcome.daysAway == 1 ? "a day" : "\(welcome.daysAway) days"
        return welcome.openCount == 0
            ? "It\u{2019}s been \(gap). Nothing\u{2019}s waiting on you. Start wherever you like."
            : "It\u{2019}s been \(gap). No catching up needed. Here\u{2019}s what\u{2019}s still open."
    }

    private var moreLabel: String {
        let remaining = welcome.openCount - welcome.highlights.count
        return remaining > 0 ? "See all, plus \(remaining) more" : "Open Tasks"
    }

    private func highlightRow(_ task: MemoryTask) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.sm) {
            Image(systemName: task.promisedTo == nil ? "circle" : "hand.raised")
                .font(OrbitTypography.footnote)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .lineLimit(2)
                if let detail = detail(for: task) {
                    Text(detail)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(for task: MemoryTask) -> String? {
        var parts: [String] = []
        if let person = task.promisedTo { parts.append("For \(person)") }
        if let due = task.dueDate {
            parts.append("Due \(due.formatted(.relative(presentation: .named)))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview("Welcome back") {
    let now = Date()
    WelcomeBackCard(
        model: HomeWelcomeBack(
            welcome: WelcomeBack(
                daysAway: 9,
                highlights: [
                    MemoryTask(title: "Send the photos", createdAt: now, promisedTo: "Sam"),
                    MemoryTask(title: "Pay rent", dueDate: now.addingTimeInterval(86_400), createdAt: now),
                ],
                openCount: 5
            ),
            onOpenTasks: {},
            onDismiss: {}
        ),
        accent: .blue
    )
    .padding()
}
