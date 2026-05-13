import SwiftUI

/// The standard screen container. Applies Orbit's background, edge-to-edge
/// content area, and a calm default content padding. Use as the outermost
/// view of every feature root.
public struct OrbitScreen<Content: View>: View {
    private let content: Content
    private let horizontalPadding: CGFloat

    public init(
        horizontalPadding: CGFloat = OrbitSpacing.pageHorizontal,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        ZStack {
            OrbitColor.background
                .ignoresSafeArea()
            content
                .padding(.horizontal, horizontalPadding)
        }
    }
}
