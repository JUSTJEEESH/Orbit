import SwiftUI
import OrbitDesignSystem

/// Shared brand chrome used at the top of every share card. Keeps the
/// "Orbit" wordmark consistent in weight, color, and dot alignment — all
/// three cards inherit the same vertical rhythm so they read as a series
/// even when shared apart.
struct ShareCardBrandMark: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(OrbitColor.textPrimary)
                .frame(width: 12, height: 12)
            Text("Orbit")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(OrbitColor.textPrimary)
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
/// solid background, edge padding. Renders an opaque rect (no rounded
/// corners) because share targets re-crop / re-shape the image at their
/// own discretion.
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
