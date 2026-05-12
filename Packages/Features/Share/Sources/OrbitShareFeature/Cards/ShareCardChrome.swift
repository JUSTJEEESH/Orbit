import SwiftUI
import OrbitDesignSystem

// MARK: - Top rail

/// Asymmetric brand chrome at the top of every card.
///
/// Logo + wordmark on the left, a small all-caps stamp on the right.
/// The stamp is per-card (e.g., "MEMORY", "DAILY RECAP", "YEAR IN
/// REVIEW") and replaces the in-line eyebrow inside the body — moving
/// it up here frees the hero column for one dominant idea.
///
/// Typography is plain SF Pro Display (not rounded). Rounded reads
/// "playful tech app"; default SF reads "editorial," which is the
/// Apple Journal / Things 3 register we want.
struct ShareCardTopRail: View {
    let stamp: String?

    @Environment(\.orbitTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Image("OrbitLogo", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .foregroundStyle(theme.primary)
                .accessibilityHidden(true)

            Text("Orbit")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)

            Spacer()

            if let stamp {
                Text(stamp.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(2.6)
                    .foregroundStyle(OrbitColor.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Hairlines and dividers

/// Hairline rule — the kind Apple Journal uses to separate sections
/// without screaming for attention. 1pt at the rendered scale, which
/// at 1080-wide produces a visually crisp ~3px line on retina exports.
struct ShareCardHairline: View {
    var body: some View {
        Rectangle()
            .fill(OrbitColor.separator)
            .frame(height: 1)
    }
}

/// Small all-caps eyebrow paired with a value. Used for stat rows on
/// the Year-in-Review card; the long fixed label column lines them up
/// vertically the way a magazine masthead does.
struct ShareCardLabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 14, weight: .medium))
                .tracking(2.0)
                .foregroundStyle(OrbitColor.textTertiary)
                .frame(width: 360, alignment: .leading)
            Text(value)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(OrbitColor.textPrimary)
                .lineLimit(1)
            Spacer()
        }
    }
}

// MARK: - Bottom publisher line

/// "Publisher" line at the very bottom of every card. Reads like the
/// imprint on a printed page. Repeats the logo at small size + tagline
/// so a card shared in isolation always explains what Orbit is.
struct ShareCardPublisherLine: View {
    @Environment(\.orbitTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("OrbitLogo", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(theme.primary)
                .accessibilityHidden(true)
            Text("Orbit · Your second brain")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OrbitColor.textTertiary)
            Spacer()
        }
    }
}

// MARK: - Surface

/// Outer container used by every card — fixed 1080×1350 pixel canvas,
/// solid background, generous padding. The background resolves to
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
            .padding(.horizontal, 72)
            .padding(.vertical, 80)
        }
        .frame(width: 1080, height: 1350)
    }
}
