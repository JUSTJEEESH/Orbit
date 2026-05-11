import SwiftUI

public struct OrbitCard<Content: View>: View {
    public enum Elevation: Sendable {
        case flat
        case resting
        case lifted
    }

    private let content: Content
    private let elevation: Elevation
    private let padding: CGFloat
    private let cornerRadius: CGFloat

    public init(
        elevation: Elevation = .resting,
        padding: CGFloat = OrbitSpacing.lg,
        cornerRadius: CGFloat = OrbitRadius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrbitColor.surface, in: .rect(cornerRadius: cornerRadius))
            .orbitShadow(shadow)
    }

    private var shadow: OrbitShadow {
        switch elevation {
        case .flat:    return .none
        case .resting: return .resting
        case .lifted:  return .lifted
        }
    }
}
