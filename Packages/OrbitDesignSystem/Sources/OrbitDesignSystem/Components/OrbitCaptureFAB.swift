import SwiftUI
import OrbitKit

/// The persistent floating capture button. Lives above all content; never
/// recede behind chrome. This is the most important interactive surface in
/// Orbit — keep it instantly tappable, instantly responsive.
public struct OrbitCaptureFAB: View {
    private let action: @MainActor () -> Void
    @State private var isPressed = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                .modifier(FABBackground(reduceTransparency: reduceTransparency))
                .orbitShadow(.lifted)
        }
        .buttonStyle(OrbitPressedButtonStyle())
        .accessibilityLabel("Capture")
        .accessibilityHint("Open the capture sheet to save a new memory.")
        .accessibilityAddTraits(.isButton)
    }
}

/// Honors `accessibilityReduceTransparency`: when on, swap the iOS 26
/// Liquid Glass material for an opaque high-contrast surface so the FAB
/// stays legible for users who can't tolerate refractive backgrounds.
private struct FABBackground: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(OrbitColor.surfaceMuted, in: .circle)
                .overlay(
                    Circle()
                        .stroke(OrbitColor.separator, lineWidth: 0.5)
                )
        } else {
            // iOS 26 Liquid Glass — pure translucent material, no
            // tint. The orb picks up whatever the user scrolls
            // behind it: timeline rows, the recap card's serif
            // text, the home greeting. Tinting white (as we did
            // before) makes the orb look solid because the bright
            // tint masks any refraction.
            content.glassEffect(.regular.interactive(), in: .circle)
        }
    }
}
