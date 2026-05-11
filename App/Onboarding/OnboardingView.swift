import SwiftUI
import AuthenticationServices
import OrbitDesignSystem
import OrbitKit
import OrbitAccount

/// First-launch flow. Four paged screens, ending with Sign in with Apple
/// (optional) + Continue as Guest. Marks completion in UserDefaults so we
/// never show it twice.
struct OnboardingView: View {
    @State private var page: Int = 0
    @Bindable var account: AccountService
    let onComplete: @MainActor () -> Void

    private static let storageKey = "orbit.onboarding.completed"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: storageKey)
    }

    var body: some View {
        OrbitScreen {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    capturePage.tag(1)
                    aiPage.tag(2)
                    signInPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(OrbitMotion.smooth, value: page)

                dotsAndAction
                    .padding(.bottom, OrbitSpacing.xxxl)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        page(
            eyebrow: "ORBIT",
            title: "Your second brain",
            body: "A calm place for everything you don't want to forget — thoughts, voice notes, links, photos.",
            icon: "circle.hexagongrid"
        )
    }

    private var capturePage: some View {
        page(
            eyebrow: "CAPTURE FIRST",
            title: "Save anything in under two seconds",
            body: "Tap the circle. Type, speak, paste, snap. Move on. Orbit holds it for you.",
            icon: "plus.circle.fill"
        )
    }

    private var aiPage: some View {
        page(
            eyebrow: "QUIET INTELLIGENCE",
            title: "Orbit organizes the rest",
            body: "On-device AI summarizes, categorizes, and resurfaces what matters — privately, automatically.",
            icon: "sparkles"
        )
    }

    private var signInPage: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text("SIGN IN")
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textTertiary)
                Text("Make it yours")
                    .font(OrbitTypography.largeTitle)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text("Sign in with Apple to sync across your devices. Or continue as a guest — you can sign in any time.")
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, OrbitSpacing.xxxl)

            Spacer()

            VStack(spacing: OrbitSpacing.sm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    account.handle(result)
                    if case .signedIn = account.state {
                        Haptics.play(.success)
                        finish()
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: OrbitRadius.md))

                Button("Continue as guest", action: finish)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .padding(.top, OrbitSpacing.xs)
            }
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
    }

    private func page(eyebrow: String, title: String, body: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(OrbitColor.textPrimary)
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text(eyebrow)
                    .font(OrbitTypography.caption)
                    .foregroundStyle(OrbitColor.textTertiary)
                Text(title)
                    .font(OrbitTypography.largeTitle)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(body)
                    .font(OrbitTypography.body)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var dotsAndAction: some View {
        VStack(spacing: OrbitSpacing.md) {
            HStack(spacing: OrbitSpacing.xs) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index == page ? OrbitColor.textPrimary : OrbitColor.separator)
                        .frame(width: 7, height: 7)
                }
            }
            if page < 3 {
                OrbitButton("Continue", style: .primary, size: .large) {
                    Haptics.play(.tap)
                    withAnimation(OrbitMotion.smooth) { page += 1 }
                }
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
            }
        }
    }

    private func finish() {
        Self.markCompleted()
        onComplete()
    }
}
