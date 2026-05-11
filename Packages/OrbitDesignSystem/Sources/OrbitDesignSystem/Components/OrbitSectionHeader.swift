import SwiftUI

/// Section header used inside scroll views and lists. Bold, editorial, paired
/// with optional trailing accessory.
public struct OrbitSectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: OrbitSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OrbitTypography.title)
                    .foregroundStyle(OrbitColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                }
            }
            Spacer(minLength: OrbitSpacing.sm)
            trailing
        }
        .padding(.vertical, OrbitSpacing.xs)
    }
}
