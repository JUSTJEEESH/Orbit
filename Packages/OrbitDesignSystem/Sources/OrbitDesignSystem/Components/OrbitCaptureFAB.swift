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
                // iOS 26 Liquid Glass — the glass IS the surface. Tinted
                // toward textPrimary so the FAB still reads as Orbit's
                // dark control, but content underneath refracts through
                // the orb (timeline cells, recap card, etc.). Without
                // a tinted glass, an opaque background would block
                // refraction and the effect would be invisible.
                .glassEffect(
                    .regular.tint(OrbitColor.textPrimary).interactive(),
                    in: .circle
                )
                .orbitShadow(.lifted)
        }
        .buttonStyle(OrbitPressedButtonStyle())
        .accessibilityLabel("Capture")
        .accessibilityHint("Open the capture sheet to save a new memory.")
    }
}
