import SwiftUI
import OrbitDesignSystem
import OrbitDomain

public struct TimelineView: View {
    public init() {}

    public var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    Text("Timeline")
                        .font(OrbitTypography.largeTitle)
                        .padding(.top, OrbitSpacing.lg)

                    emptyState
                    Spacer(minLength: 96)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            Text("Nothing here yet")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Captured memories will appear here in a calm, scrollable history. Day by day, week by week.")
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, OrbitSpacing.xxl)
    }
}

#Preview {
    TimelineView().preferredColorScheme(.dark)
}
