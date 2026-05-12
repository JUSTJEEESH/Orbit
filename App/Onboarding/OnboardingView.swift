import SwiftUI
import AuthenticationServices
import OrbitDesignSystem
import OrbitKit
import OrbitAccount

/// First-launch flow, reduced to two screens — the signature moment and
/// sign-in. The opening is a quiet orbital animation that resolves into a
/// single point, set to the user's accent. Premium-feel onboarding is about
/// what you leave out: there is no skip, no progress dots, no "swipe to
/// continue" — just one beat that says *this is a different kind of app.*
struct OnboardingView: View {
    private enum Stage { case moment, signIn }

    @State private var stage: Stage = .moment
    @Bindable var account: AccountService
    let onComplete: @MainActor () -> Void

    var body: some View {
        OrbitScreen {
            ZStack {
                switch stage {
                case .moment:
                    momentScene
                        .transition(.opacity)
                case .signIn:
                    signInScene
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: stage)
        }
    }

    // MARK: - Moment

    private var momentScene: some View {
        VStack(spacing: 0) {
            Spacer()
            OrbitMoment()
                .frame(height: 240)
            Spacer().frame(height: OrbitSpacing.xxxl)
            Text("Orbit")
                .font(.system(size: 44, weight: .semibold, design: .serif))
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Memories find their orbit.")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.sm)
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
                .multilineTextAlignment(.center)
            Spacer()
            OrbitButton("Continue", style: .primary, size: .large) {
                Haptics.play(.tap)
                stage = .signIn
            }
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            .padding(.bottom, OrbitSpacing.xxxl)
        }
    }

    // MARK: - Sign in

    private var signInScene: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: OrbitSpacing.xxxl * 2)
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text("Make it yours")
                    .font(OrbitTypography.largeTitle)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Sign in with Apple to sync across your devices. Or continue as a guest — you can sign in any time.")
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: OrbitSpacing.sm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    account.handle(result)
                    if case .signedIn = account.state {
                        Haptics.play(.success)
                        onComplete()
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: OrbitRadius.md))

                Button("Continue as guest", action: onComplete)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .padding(.top, OrbitSpacing.xs)
            }
            .padding(.bottom, OrbitSpacing.xxxl)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - OrbitMoment

/// The signature opening visual: three glowing dots tracing concentric
/// orbits, then converging into a single bright point at the center.
///
/// Tightly choreographed: the orbital phase lasts ~2.4s before the dots
/// pull in over ~0.9s and the center swells. The rotation is driven by
/// `TimelineView(.animation)` rather than `withAnimation`, so it stays
/// hitch-free across navigation transitions.
///
/// Respects `accessibilityReduceMotion` — when on, no animation runs and
/// the final converged state is rendered immediately.
private struct OrbitMoment: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitTheme) private var orbitTheme

    @State private var didConverge = false
    @State private var startedAt = Date()

    /// Concentric orbit definitions. Slight phase offsets keep the dots
    /// from lining up into a stiff equilateral shape.
    private struct OrbitalDot {
        let radius: CGFloat
        let speed: Double      // radians/second
        let phase: Double      // radians offset
        let opacity: Double
    }

    private let orbits: [OrbitalDot] = [
        .init(radius: 44,  speed: 0.95, phase: 0,        opacity: 0.95),
        .init(radius: 70,  speed: 0.66, phase: 1.7,      opacity: 0.75),
        .init(radius: 96,  speed: 0.48, phase: 3.6,      opacity: 0.55)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            ZStack {
                if reduceMotion {
                    // Static converged state.
                    centerDot(scale: 1.6, opacity: 1.0)
                } else {
                    let convergence = convergenceProgress(at: elapsed)
                    let centerScale = 1.0 + 0.6 * convergence

                    ForEach(orbits.indices, id: \.self) { index in
                        let orbit = orbits[index]
                        let position = orbitalPosition(
                            elapsed: elapsed,
                            orbit: orbit,
                            convergence: convergence
                        )
                        Circle()
                            .fill(orbitTheme.primary)
                            .frame(width: 10, height: 10)
                            .opacity(orbit.opacity * (1 - convergence * 0.85))
                            .offset(x: position.x, y: position.y)
                    }
                    centerDot(scale: centerScale, opacity: 1.0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startedAt = Date() }
    }

    private func centerDot(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(orbitTheme.primary)
            .frame(width: 12, height: 12)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: orbitTheme.primary.opacity(0.45), radius: 18)
    }

    /// Returns 0 while the dots are still orbiting, ramping smoothly to 1 as
    /// they converge. Uses a cosine ease so the pull-in feels gravitational
    /// rather than linear.
    private func convergenceProgress(at elapsed: TimeInterval) -> CGFloat {
        let convergeStart: TimeInterval = 2.4
        let convergeDuration: TimeInterval = 0.9
        let raw = (elapsed - convergeStart) / convergeDuration
        let clamped = max(0, min(1, raw))
        // Cosine ease-in-out.
        return CGFloat(0.5 - 0.5 * cos(.pi * clamped))
    }

    private func orbitalPosition(
        elapsed: TimeInterval,
        orbit: OrbitalDot,
        convergence: CGFloat
    ) -> CGPoint {
        let angle = elapsed * orbit.speed + orbit.phase
        let radius = orbit.radius * (1 - convergence)
        return CGPoint(
            x: radius * CGFloat(cos(angle)),
            y: radius * CGFloat(sin(angle))
        )
    }
}
