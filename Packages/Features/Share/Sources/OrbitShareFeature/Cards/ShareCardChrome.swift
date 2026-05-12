import SwiftUI
import OrbitDesignSystem

/// Shared brand chrome used at the top of every share card.
///
/// Three vertically-stacked elements give every card the same opening
/// move: the real Orbit glyph (tinted with the active theme's accent),
/// the wordmark in SF Rounded, and a single-line tagline that tells
/// anyone who sees the shared image what Orbit actually is. The logo
/// asset is a vector SVG with template-rendering enabled, so theme
/// color always paints through.
struct ShareCardBrandMark: View {
    @Environment(\.orbitTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image("OrbitLogo", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .foregroundStyle(theme.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Orbit")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Your second brain")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            Spacer()
        }
    }
}

/// Bottom-of-card meta line. Subtle, all-caps, generous tracking — the
/// kind of footer Apple Music / Things 3 share cards use to ground the
/// composition.
struct ShareCardFooterLine: View {
    let leading: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(leading.uppercased())
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(OrbitColor.textTertiary)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(OrbitColor.textTertiary)
            }
        }
    }
}

/// Outer container used by every card — fixed 1080×1350 pixel canvas,
/// solid background, edge padding. The background resolves to
/// `OrbitColor.background` which is itself a dynamic light/dark color,
/// so the card respects whatever `colorScheme` the renderer is told to
/// use. Renders an opaque rect (no rounded corners) because share
/// targets re-crop / re-shape the image at their own discretion.
struct ShareCardSurface<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            OrbitColor.background
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 72)
        }
        .frame(width: 1080, height: 1350)
    }
}
