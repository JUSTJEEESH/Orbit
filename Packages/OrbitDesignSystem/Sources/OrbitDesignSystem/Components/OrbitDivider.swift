import SwiftUI

/// Hairline divider tuned to the design system.
public struct OrbitDivider: View {
    private let strong: Bool

    public init(strong: Bool = false) {
        self.strong = strong
    }

    public var body: some View {
        Rectangle()
            .fill(strong ? OrbitColor.separatorStrong : OrbitColor.separator)
            .frame(height: 0.5)
            .frame(maxWidth: .infinity)
    }
}
