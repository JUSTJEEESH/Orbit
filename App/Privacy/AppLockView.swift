import SwiftUI
import OrbitDesignSystem
import OrbitKit

/// Full-screen cover shown while Orbit is locked. Also hides memories from
/// the app switcher snapshot.
struct AppLockView: View {
    let lock: AppLockService

    var body: some View {
        VStack(spacing: OrbitSpacing.lg) {
            Spacer()
            Image("OrbitLogo")
                .resizable()
                .scaledToFit()
                .frame(width: OrbitSpacing.xxxl * 1.5, height: OrbitSpacing.xxxl * 1.5)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityHidden(true)
            Text("Orbit is locked")
                .font(OrbitTypography.title2)
                .foregroundStyle(OrbitColor.textPrimary)
            Spacer()
            OrbitButton("Unlock with \(lock.methodName)", systemImage: "lock.open", style: .primary, size: .large) {
                Task { await lock.unlock() }
            }
            .disabled(lock.isAuthenticating)
            .padding(.horizontal, OrbitSpacing.xl)
            .padding(.bottom, OrbitSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrbitColor.background.ignoresSafeArea())
        .task { await lock.unlock() }
    }
}
