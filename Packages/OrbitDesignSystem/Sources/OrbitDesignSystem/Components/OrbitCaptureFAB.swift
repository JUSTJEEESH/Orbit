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
                // Plus uses textPrimary so it inverts with light/dark
                // mode and stays high-contrast against whatever is
                // refracting through the glass.
                .foregroundStyle(OrbitColor.textPrimary)
                .frame(width: 64, height: 64)
                // iOS 26 Liquid Glass — pure translucent material, no
                // tint. The orb picks up whatever the user scrolls
                // behind it: timeline rows, the recap card's serif
                // text, the home greeting. Tinting white (as we did
                // before) makes the orb look solid because the bright
                // tint masks any refraction.
                .glassEffect(.regular.interactive(), in: .circle)
                .orbitShadow(.lifted)
        }
        .buttonStyle(OrbitPressedButtonStyle())
        .accessibilityLabel("Capture")
        .accessibilityHint("Open the capture sheet to save a new memory.")
    }
}
