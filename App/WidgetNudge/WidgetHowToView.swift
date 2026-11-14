import SwiftUI
import OrbitDesignSystem

/// Three steps to add Orbit's widget. iOS doesn't let apps add widgets
/// themselves, so the best Orbit can do is make the steps obvious.
struct WidgetHowToView: View {
    let onDone: @MainActor () -> Void

    private let steps: [(symbol: String, text: String)] = [
        ("hand.tap", "Touch and hold an empty spot on your Home Screen until the apps jiggle."),
        ("plus.circle", "Tap Edit in the top corner, then Add Widget."),
        ("magnifyingglass", "Search for Orbit, choose a size, and tap Add Widget."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
            Text("Add the Orbit widget")
                .font(OrbitTypography.title)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, OrbitSpacing.xl)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: OrbitSpacing.md) {
                    Text("\(index + 1)")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textInverted)
                        .frame(width: OrbitSpacing.xxl, height: OrbitSpacing.xxl)
                        .background(OrbitColor.textPrimary, in: .circle)
                        .accessibilityHidden(true)
                    Label(step.text, systemImage: step.symbol)
                        .labelStyle(.titleOnly)
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            OrbitButton("Done", style: .primary, size: .large) { onDone() }
        }
        .padding(.horizontal, OrbitSpacing.xl)
        .padding(.bottom, OrbitSpacing.lg)
        .background(OrbitColor.background.ignoresSafeArea())
    }
}

#Preview {
    WidgetHowToView(onDone: {})
}
