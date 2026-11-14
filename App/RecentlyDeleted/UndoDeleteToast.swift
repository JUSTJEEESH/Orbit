import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// "Memory deleted · Undo" — shown for a few seconds after any delete.
/// Deleting only moves a memory to Recently Deleted, so Undo is exact.
struct UndoDeleteToast: View {
    let onUndo: @MainActor () -> Void

    var body: some View {
        HStack(spacing: OrbitSpacing.md) {
            Image(systemName: "trash")
                .foregroundStyle(OrbitColor.textSecondary)
                .accessibilityHidden(true)
            Text("Memory deleted")
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textPrimary)
            Spacer(minLength: OrbitSpacing.sm)
            Button {
                Haptics.play(.success)
                onUndo()
            } label: {
                Text("Undo")
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .frame(minWidth: OrbitHitTarget.minimum, minHeight: OrbitHitTarget.minimum)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, OrbitSpacing.lg)
        .padding(.trailing, OrbitSpacing.sm)
        .background(OrbitColor.surfaceElevated, in: .capsule)
        .overlay(Capsule().strokeBorder(OrbitColor.separator))
        .orbitShadow(.lifted)
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo") { onUndo() }
    }
}

#Preview {
    UndoDeleteToast(onUndo: {})
        .padding(.vertical, OrbitSpacing.xxl)
        .background(OrbitColor.background)
}
