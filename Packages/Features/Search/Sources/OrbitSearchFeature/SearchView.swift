import SwiftUI
import OrbitDesignSystem
import OrbitDomain

public struct SearchView: View {
    @State private var query: String = ""

    public init() {}

    public var body: some View {
        OrbitScreen {
            VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                Text("Search")
                    .font(OrbitTypography.largeTitle)
                    .padding(.top, OrbitSpacing.lg)

                OrbitTextField(
                    "Ask anything",
                    text: $query,
                    systemImage: "magnifyingglass"
                )

                suggestions
                Spacer()
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Try")
            HStack(spacing: OrbitSpacing.xs) {
                OrbitChip("Restaurants in Roatan")
                OrbitChip("Drone business idea")
            }
            HStack(spacing: OrbitSpacing.xs) {
                OrbitChip("From Pamela last month")
                OrbitChip("Voice notes about travel")
            }
        }
    }
}

#Preview {
    SearchView().preferredColorScheme(.dark)
}
