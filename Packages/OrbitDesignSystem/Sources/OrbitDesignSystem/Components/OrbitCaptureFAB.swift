import SwiftUI
import OrbitKit

/// The persistent floating capture button. Lives above all content; never
/// recede behind chrome. This is the most important interactive surface in
/// Orbit — keep it instantly tappable, instantly responsive.
public struct OrbitCaptureFAB: View {
    private let action: @MainActor () -> Void
    @State private var isPressed = false

    public init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.play(.impactRigid)
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(OrbitColor.textInverted)
                .frame(width: 64, height: 64)
                .background(OrbitColor.textPrimary, in: .circle)
                // iOS 26 Liquid Glass — adds a living sheen that picks up
                // the content beneath the FAB without breaking the solid-
                // color rule (the surface is still a single token; glass
                // is depth, not color).
                .glassEffect(.regular.interactive(), in: .circle)
                .orbitShadow(.lifted)
        }
        .buttonStyle(OrbitPressedButtonStyle())
        .accessibilityLabel("Capture")
        .accessibilityHint("Open the capture sheet to save a new memory.")
    }
}
