import SwiftUI
import OrbitDesignSystem

/// Placeholder shown while Home loads for the first time: the shape of the
/// real content, softly redacted, so the screen never flashes "empty".
struct HomeSkeleton: View {
    private static let rowCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Today's memories")
                .font(OrbitTypography.title3)
            ForEach(0..<Self.rowCount, id: \.self) { _ in
                OrbitCard(elevation: .resting) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                        Text("Note · 9:41 AM")
                            .font(OrbitTypography.caption)
                        Text("A memory you saved is loading here")
                            .font(OrbitTypography.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your memories")
    }
}
