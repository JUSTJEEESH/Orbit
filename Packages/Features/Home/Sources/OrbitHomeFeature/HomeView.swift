import SwiftUI
import OrbitDesignSystem
import OrbitDomain

public struct HomeView: View {
    public init() {}

    public var body: some View {
        OrbitScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xxl) {
                    greeting
                    todaySection
                    resurfacingSection
                    Spacer(minLength: 96) // breathing room above the FAB
                }
                .padding(.top, OrbitSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xxs) {
            Text("Good morning")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
            Text("Your second brain")
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Today", subtitle: "Nothing on your plate yet")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Capture your first memory")
                        .font(OrbitTypography.bodyEmphasized)
                    Text("Tap the round button below to start. Orbit organizes the rest.")
                        .font(OrbitTypography.callout)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
        }
    }

    private var resurfacingSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Resurfaced")
            Text("Orbit will surface forgotten ideas here as your memory grows.")
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
        }
    }
}

#Preview {
    HomeView().preferredColorScheme(.dark)
}
