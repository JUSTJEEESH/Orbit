import SwiftUI
import AuthenticationServices
import OrbitDesignSystem
import OrbitKit
import OrbitAccount

/// First-launch flow. Seven beats — the signature moment, two short
/// "show don't tell" explainers, permissions, theme picker, sign-in,
/// and a final wrap that hands the user off to a populated Home.
///
/// The shell is a single state-driven stage; pages animate in with a
/// cross-fade-plus-slide so there's no swipe gesture to discover.
/// Premium onboarding never asks the user to figure out the navigation.
struct OnboardingView: View {
    private enum Stage: Int, CaseIterable {
        case moment, capture, intelligence, permissions, theme, signIn, welcome
    }

    @State private var stage: Stage = .moment
    @State private var permissions = PermissionsCoordinator()
    @Bindable var account: AccountService
    /// Theme picker (Stage.theme) writes through this service. The first
    /// pick during onboarding bypasses the Pro gate by design — Settings
    /// keeps its existing gate for subsequent switches.
    @Bindable var themeService: ThemeService
    let onComplete: @MainActor () -> Void
    /// Custom Reminders handler. When supplied, the Reminders row's Allow
    /// tap routes through this closure (which both prompts EventKit AND
    /// flips the sync toggle on) instead of just the bare permission
    /// request. ContentRoot wires this to `env.remindersSync.enable()`.
    let onEnableReminders: (@MainActor @Sendable () async -> Bool)?
    /// Custom Calendar handler. When supplied, the Calendar row's
    /// Allow tap routes through this closure (which both prompts
    /// EventKit AND flips Orbit's calendar sync toggle on) instead
    /// of just the bare permission request. ContentRoot wires this
    /// to `env.calendarSync.enable()`.
    let onEnableCalendar: (@MainActor @Sendable () async -> Bool)?
    /// Custom Health handler. When supplied, the Health row's Allow tap
    /// routes through this closure (which prompts HealthKit + persists
    /// the asked-once flag) instead of the bare PermissionsCoordinator
    /// path. ContentRoot wires this to `env.healthKit.requestAuthorization()`.
    let onEnableHealth: (@MainActor @Sendable () async -> Bool)?

    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OrbitScreen {
            ZStack(alignment: .top) {
                progressDots
                    .padding(.top, OrbitSpacing.lg)

                Group {
                    switch stage {
                    case .moment:        momentScene
                    case .capture:       captureScene
                    case .intelligence:  intelligenceScene
                    case .permissions:   permissionsScene
                    case .theme:         themeScene
                    case .signIn:        signInScene
                    case .welcome:       welcomeScene
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 14)),
                        removal: .opacity.combined(with: .offset(y: -14))
                    )
                )
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: stage)
        }
        .task {
            await permissions.refreshAll()
        }
    }

    // MARK: - Progress

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(Stage.allCases, id: \.rawValue) { dotStage in
                Capsule()
                    .fill(dotStage.rawValue <= stage.rawValue
                          ? orbitTheme.primary
                          : OrbitColor.separator)
                    .frame(width: dotStage == stage ? 22 : 6, height: 6)
                    .animation(reduceMotion ? nil : .spring(duration: 0.4), value: stage)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 1. Moment

    private var momentScene: some View {
        VStack(spacing: 0) {
            Spacer()
            OrbitMoment()
                .frame(width: 260, height: 260)
                .accessibilityHidden(true)
            Spacer().frame(height: OrbitSpacing.xl)
            Text("Orbit")
                .scaledFont(size: 44, weight: .semibold, design: .serif)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Memories find their orbit.")
                .scaledFont(size: 17, design: .serif)
                .italic()
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.sm)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
            Spacer()
            primaryButton("Begin") { goNext() }
        }
        .padding(.bottom, OrbitSpacing.xxxl)
    }

    // MARK: - 2. Capture explainer

    private var captureScene: some View {
        VStack(spacing: 0) {
            Spacer()
            CaptureMotif()
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)
            Spacer().frame(height: OrbitSpacing.xl)
            explainerCopy(
                title: "However it lands.",
                body: "Type a thought. Speak a voice note. Snap a photo. Paste a link. Orbit holds it all — without asking you to organize anything."
            )
            Spacer()
            primaryButton("Continue") { goNext() }
        }
        .padding(.bottom, OrbitSpacing.xxxl)
    }

    // MARK: - 3. Intelligence explainer

    private var intelligenceScene: some View {
        VStack(spacing: 0) {
            Spacer()
            IntelligenceLiveDemo()
                .frame(width: 300, height: 240)
                .accessibilityHidden(true)
            Spacer().frame(height: OrbitSpacing.xl)
            explainerCopy(
                title: "Quiet intelligence",
                body: "On-device AI sorts, summarizes, and resurfaces what matters. Nothing ever leaves your phone."
            )
            Spacer()
            primaryButton("Continue") { goNext() }
        }
        .padding(.bottom, OrbitSpacing.xxxl)
    }

    // MARK: - 4. Permissions

    private var permissionsScene: some View {
        // ScrollView is the safety net — small iPhones (especially in
        // Larger Text accessibility sizes) would otherwise clip the
        // Continue button off the bottom. The slim list below means
        // it almost never has to actually scroll on stock text size.
        VStack(spacing: 0) {
            Spacer().frame(height: OrbitSpacing.xxxl + 8)
            ScrollView {
                VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                    VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                        Text("Two essentials")
                            .font(OrbitTypography.largeTitle)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Text("They power voice notes and Daily Recap. Change either in Settings, anytime.")
                            .font(OrbitTypography.body)
                            .foregroundStyle(OrbitColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: OrbitSpacing.sm) {
                        ForEach(PermissionsCoordinator.Permission.onboardingEssentials, id: \.self) { permission in
                            permissionRow(for: permission)
                        }
                    }
                    // Quiet signpost for everything we deliberately
                    // *don't* surface up front. Discoverable, not
                    // demanded — iOS itself will ask for transcription
                    // and photo access the first time you reach for
                    // those features.
                    Text("Photos, transcription, Reminders, Calendar, Health — Orbit asks once, when you reach each.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, OrbitSpacing.pageHorizontal)
                .padding(.bottom, OrbitSpacing.lg)
            }
            .scrollIndicators(.hidden)

            primaryButton("Continue") { goNext() }
                .padding(.bottom, OrbitSpacing.xxxl)
        }
    }

    private func permissionRow(for permission: PermissionsCoordinator.Permission) -> some View {
        let status = permissions.status(for: permission)
        return OrbitCard(elevation: .resting) {
            HStack(alignment: .center, spacing: OrbitSpacing.md) {
                Image(systemName: permission.systemImage)
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(orbitTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(orbitTheme.primary.opacity(0.12), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(permission.title)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text(permission.rationale)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: OrbitSpacing.xs)
                permissionActionView(for: permission, status: status)
            }
        }
    }

    @ViewBuilder
    private func permissionActionView(
        for permission: PermissionsCoordinator.Permission,
        status: PermissionsCoordinator.Status
    ) -> some View {
        switch status {
        case .granted, .provisional:
            Image(systemName: "checkmark.circle.fill")
                .scaledFont(size: 22, weight: .semibold)
                .foregroundStyle(OrbitColor.success)
                .accessibilityLabel("Granted")
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .scaledFont(size: 22, weight: .semibold)
                .foregroundStyle(OrbitColor.warning)
                .accessibilityLabel("Denied")
        case .notDetermined:
            Button {
                Haptics.play(.tap)
                Task { await handleRequest(for: permission) }
            } label: {
                Text("Allow")
                    .font(OrbitTypography.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(orbitTheme.primary)
                    .padding(.horizontal, OrbitSpacing.md)
                    .padding(.vertical, OrbitSpacing.xs)
                    .background(orbitTheme.primary.opacity(0.12), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Allow \(permission.title)")
        }
    }

    /// Routes the Reminders permission through the host-supplied handler
    /// so a single "Allow" tap both grants EventKit access and turns Orbit
    /// sync on. Health follows the same pattern so onboarding can prompt
    /// HealthKit + persist Orbit's "asked once" flag in one tap. Other
    /// permissions use the coordinator's built-in request.
    @MainActor
    private func handleRequest(for permission: PermissionsCoordinator.Permission) async {
        // For Reminders / Calendar / Health we route through the
        // host-supplied closure so a single Allow tap both grants
        // the OS permission AND flips Orbit's downstream sync on.
        // The closure's return value isn't authoritative for the
        // row checkmark, though — it can report false for
        // non-permission reasons (no Reminders list available, no
        // writeable Calendar source). After those closures run we
        // pull the system source of truth via `refreshAll()` so the
        // green check / orange X reflects the actual EventKit /
        // HealthKit state.
        //
        // For the simple permissions (microphone, speech, photos,
        // notifications) `request(_:)` already writes the resolved
        // status into the coordinator, so no extra refresh is
        // needed — and skipping it avoids a system-framework hop
        // (UNUserNotificationCenter + EKEventStore re-queries) that
        // tripped a libdispatch queue assertion right after the
        // Speech prompt resolved on some iOS builds.
        switch permission {
        case .reminders:
            if let onEnableReminders {
                _ = await onEnableReminders()
                await permissions.refreshAll()
            } else {
                _ = await permissions.request(permission)
            }
        case .calendar:
            if let onEnableCalendar {
                _ = await onEnableCalendar()
                await permissions.refreshAll()
            } else {
                _ = await permissions.request(permission)
            }
        case .health:
            if let onEnableHealth {
                _ = await onEnableHealth()
                await permissions.refreshAll()
            } else {
                _ = await permissions.request(permission)
            }
        default:
            _ = await permissions.request(permission)
        }
    }

    // MARK: - 5. Theme picker (new)

    /// Personalization moment. Tapping a swatch live-previews the
    /// accent across the entire onboarding shell (the dots, primary
    /// buttons, permission icons), so the user sees the change
    /// instantly. Free for the first pick — the existing ProGate.themes
    /// in Settings governs *subsequent* switches.
    private var themeScene: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: OrbitSpacing.xxxl + 8)
            VStack(alignment: .leading, spacing: OrbitSpacing.lg) {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Make it yours")
                        .font(OrbitTypography.largeTitle)
                        .foregroundStyle(OrbitColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Sets the accent everywhere. Change it in Settings, anytime.")
                        .font(OrbitTypography.body)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: OrbitSpacing.md),
                        GridItem(.flexible())
                    ],
                    spacing: OrbitSpacing.md
                ) {
                    ForEach(OrbitTheme.all) { theme in
                        themeSwatch(theme)
                    }
                }
            }
            .padding(.horizontal, OrbitSpacing.pageHorizontal)
            Spacer()
            primaryButton("Continue") { goNext() }
                .padding(.bottom, OrbitSpacing.xxxl)
        }
    }

    private func themeSwatch(_ theme: OrbitTheme) -> some View {
        let isSelected = themeService.theme.id == theme.id
        return Button {
            Haptics.play(.tap)
            themeService.select(theme)
        } label: {
            VStack(spacing: OrbitSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 68, height: 68)
                        .shadow(color: theme.primary.opacity(0.35), radius: 14)
                    if isSelected {
                        Circle()
                            .stroke(OrbitColor.textPrimary, lineWidth: 2)
                            .frame(width: 80, height: 80)
                    }
                }
                .frame(width: 88, height: 88)
                Text(theme.name)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
                Text(theme.promotionalCopy)
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OrbitSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: OrbitRadius.md)
                    .fill(isSelected ? theme.primary.opacity(0.08) : Color.clear)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityHint(theme.promotionalCopy)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 6. Sign in

    private var signInScene: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: OrbitSpacing.xxxl * 2)
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                Text("Across your devices")
                    .font(OrbitTypography.largeTitle)
                    .foregroundStyle(OrbitColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Sign in with Apple to sync your memories everywhere. Or continue as a guest — you can sign in any time.")
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
                        goNext()
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: OrbitRadius.md))

                Button("Continue as guest") {
                    Haptics.play(.tap)
                    goNext()
                }
                .font(OrbitTypography.bodyEmphasized)
                .foregroundStyle(OrbitColor.textSecondary)
                .padding(.top, OrbitSpacing.xs)
            }
            .padding(.bottom, OrbitSpacing.xxxl)
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 7. Welcome wrap-up (new)

    /// Arrival beat. Three placeholder cards bob gently to preview the
    /// shape of the welcome-seed memories the user will see on Home a
    /// moment later. Tapping "Open Orbit" fires `onComplete()`, which
    /// flips `onboardingComplete` and plants the welcome seed (see
    /// ContentRoot in OrbitApp.swift).
    private var welcomeScene: some View {
        VStack(spacing: 0) {
            Spacer()
            WelcomeMotif()
                .frame(width: 300, height: 220)
                .accessibilityHidden(true)
            Spacer().frame(height: OrbitSpacing.xl)
            explainerCopy(
                title: "Your Orbit is ready",
                body: "Three notes are waiting on Home. Add your first whenever a thought lands."
            )
            Spacer()
            primaryButton("Open Orbit") {
                Haptics.play(.success)
                onComplete()
            }
        }
        .padding(.bottom, OrbitSpacing.xxxl)
    }

    // MARK: - Helpers

    private func explainerCopy(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Text(title)
                .font(OrbitTypography.largeTitle)
                .foregroundStyle(OrbitColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
    }

    private func primaryButton(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        OrbitButton(title, style: .primary, size: .large) {
            Haptics.play(.tap)
            action()
        }
        .padding(.horizontal, OrbitSpacing.pageHorizontal)
    }

    private func goNext() {
        guard let next = Stage(rawValue: stage.rawValue + 1) else {
            onComplete()
            return
        }
        stage = next
    }
}

// MARK: - OrbitMoment

/// Signature opening visual. Three glowing dots trace concentric orbits,
/// pull in toward the center, and dissolve as the Orbit logo materializes
/// in their place. Driven by a `TimelineView(.animation)` so the rotation
/// stays hitch-free even when the parent stage transitions in.
///
/// Respects `accessibilityReduceMotion` — when on, only the resolved logo
/// is rendered. A subtle success haptic fires once at the moment the logo
/// fully resolves (~2.85s in), so the brand reveal lands physically as
/// well as visually.
private struct OrbitMoment: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitTheme) private var orbitTheme

    @State private var startedAt = Date()
    @State private var didHaptic = false

    private struct OrbitalDot {
        let radius: CGFloat
        let speed: Double
        let phase: Double
        let opacity: Double
    }

    private let orbits: [OrbitalDot] = [
        .init(radius: 50,  speed: 0.95, phase: 0,   opacity: 0.95),
        .init(radius: 80,  speed: 0.66, phase: 1.7, opacity: 0.75),
        .init(radius: 110, speed: 0.48, phase: 3.6, opacity: 0.55)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = reduceMotion ? 5.0 : timeline.date.timeIntervalSince(startedAt)
            let converge = convergence(at: elapsed)
            let logoReveal = logoReveal(at: elapsed)

            ZStack {
                if !reduceMotion {
                    ForEach(orbits.indices, id: \.self) { index in
                        let orbit = orbits[index]
                        let position = orbitalPosition(
                            elapsed: elapsed,
                            orbit: orbit,
                            convergence: converge
                        )
                        Circle()
                            .fill(orbitTheme.primary)
                            .frame(width: 10, height: 10)
                            .opacity(orbit.opacity * (1 - converge) * (1 - logoReveal))
                            .offset(x: position.x, y: position.y)
                            .shadow(color: orbitTheme.primary.opacity(0.35), radius: 12)
                    }
                }

                Image("OrbitLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(orbitTheme.primary)
                    .frame(width: 180, height: 180)
                    .scaleEffect(0.85 + 0.15 * logoReveal)
                    .opacity(logoReveal)
                    .shadow(color: orbitTheme.primary.opacity(0.35 * logoReveal), radius: 26)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: logoReveal >= 0.98) { _, fullyResolved in
                if fullyResolved, !didHaptic, !reduceMotion {
                    didHaptic = true
                    Haptics.play(.success)
                }
            }
        }
        .onAppear { startedAt = Date() }
    }

    private func convergence(at elapsed: TimeInterval) -> CGFloat {
        let start: TimeInterval = 2.0
        let duration: TimeInterval = 0.85
        let raw = (elapsed - start) / duration
        let t = max(0, min(1, raw))
        return CGFloat(0.5 - 0.5 * cos(.pi * t))
    }

    private func logoReveal(at elapsed: TimeInterval) -> CGFloat {
        let start: TimeInterval = 2.55
        let duration: TimeInterval = 0.6
        let raw = (elapsed - start) / duration
        let t = max(0, min(1, raw))
        return CGFloat(0.5 - 0.5 * cos(.pi * t))
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

// MARK: - CaptureMotif

/// Compact "what you can capture" illustration: a central FAB-like circle
/// with four small chip icons orbiting at a fixed angle. Conveys the four
/// capture modes without literal phone screenshots.
private struct CaptureMotif: View {
    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private struct Chip: Identifiable {
        let id = UUID()
        let symbol: String
        let angle: Double
    }

    private let chips: [Chip] = [
        .init(symbol: "text.alignleft", angle: -.pi / 2),
        .init(symbol: "waveform",       angle: 0),
        .init(symbol: "photo",          angle: .pi / 2),
        .init(symbol: "link",           angle: .pi)
    ]

    var body: some View {
        ZStack {
            // Central FAB
            Circle()
                .stroke(orbitTheme.primary.opacity(0.18), lineWidth: 1)
                .frame(width: 200, height: 200)
            Circle()
                .stroke(orbitTheme.primary.opacity(0.10), lineWidth: 1)
                .frame(width: 240, height: 240)
            Circle()
                .fill(orbitTheme.primary)
                .frame(width: 78, height: 78)
                .shadow(color: orbitTheme.primary.opacity(0.45), radius: 22)
                .overlay(
                    Image(systemName: "plus")
                        .scaledFont(size: 30, weight: .semibold)
                        .foregroundStyle(OrbitColor.textInverted)
                )
                .scaleEffect(pulse && !reduceMotion ? 1.06 : 1.0)
                .animation(
                    reduceMotion
                        ? .default
                        : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: pulse
                )

            ForEach(chips) { chip in
                chipBubble(symbol: chip.symbol, angle: chip.angle)
            }
        }
        .onAppear { pulse = true }
    }

    private func chipBubble(symbol: String, angle: Double) -> some View {
        let radius: CGFloat = 100
        let x = radius * CGFloat(cos(angle))
        let y = radius * CGFloat(sin(angle))
        return Image(systemName: symbol)
            .scaledFont(size: 16, weight: .semibold)
            .foregroundStyle(orbitTheme.primary)
            .frame(width: 40, height: 40)
            .background(OrbitColor.surface, in: .circle)
            .overlay(Circle().stroke(orbitTheme.primary.opacity(0.18), lineWidth: 1))
            .offset(x: x, y: y)
    }
}

// MARK: - IntelligenceLiveDemo

/// "Show, don't tell" demonstration of Orbit's AI. A sample memory text
/// types in character-by-character, a subtle sparkle fades in (the
/// "thinking" beat), then three chips animate in around the card — the
/// category (`health`), the extracted entity (`Pamela`), and a saved
/// checkmark. Total run time ~3.5s. Driven by `TimelineView(.animation)`
/// so the typewriter effect is smooth regardless of the parent stage
/// transition.
///
/// The sample text and chip content were locked during the onboarding
/// copy pass — if those words change, the entity-extraction and category
/// labels must stay grounded in what `FoundationModelsAdapter` would
/// actually produce. Lying here breaks the trust that the rest of the
/// onboarding is building.
private struct IntelligenceLiveDemo: View {
    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var startedAt = Date()

    private let sampleText = "Run with Pamela this afternoon"
    /// Each chip's content + the time-offset (seconds since start) at
    /// which it begins animating in. Spaced ~0.3s apart so the three
    /// arrivals read as deliberate, not simultaneous.
    private let chips: [Chip] = [
        Chip(text: "health", delay: 2.6, position: CGPoint(x: -120, y: -40)),
        Chip(text: "Pamela", delay: 2.9, position: CGPoint(x:  130, y:  20)),
        Chip(text: "✓",      delay: 3.2, position: CGPoint(x: -100, y:  80))
    ]

    private struct Chip {
        let text: String
        let delay: TimeInterval
        let position: CGPoint
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            // ReduceMotion: skip straight to the resolved end-state so
            // the screen still communicates the same idea without motion.
            let elapsed = reduceMotion ? 4.0 : timeline.date.timeIntervalSince(startedAt)
            let typeProgress = typingProgress(at: elapsed)
            let typedChars = Int(typeProgress * CGFloat(sampleText.count))
            let visible = String(sampleText.prefix(typedChars))
            let cursorOn = typeProgress < 1 && (Int(elapsed * 2) % 2) == 0
            let sparkleAlpha = sparkleProgress(at: elapsed)

            ZStack {
                card(visibleText: visible, cursorOn: cursorOn)
                Image(systemName: "sparkles")
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(orbitTheme.primary)
                    .offset(x: 100, y: -70)
                    .opacity(sparkleAlpha)
                    .scaleEffect(0.6 + 0.4 * sparkleAlpha)
                    .shadow(color: orbitTheme.primary.opacity(0.35 * sparkleAlpha), radius: 8)

                ForEach(chips.indices, id: \.self) { i in
                    let chip = chips[i]
                    let progress = chipProgress(at: elapsed, delay: chip.delay)
                    chipView(text: chip.text)
                        .opacity(progress)
                        .scaleEffect(0.6 + 0.4 * progress)
                        .offset(x: chip.position.x, y: chip.position.y)
                }
            }
        }
        .onAppear { startedAt = Date() }
    }

    private func card(visibleText: String, cursorOn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Capsule().fill(orbitTheme.primary).frame(width: 28, height: 4)
                Capsule().fill(OrbitColor.textTertiary.opacity(0.5)).frame(width: 38, height: 4)
            }
            (Text(visibleText) + Text(cursorOn ? "│" : "").foregroundStyle(orbitTheme.primary))
                .font(OrbitTypography.body)
                .foregroundStyle(OrbitColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 56, alignment: .topLeading)
        }
        .padding(OrbitSpacing.md)
        .frame(width: 220)
        .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: OrbitRadius.md)
                .stroke(OrbitColor.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private func chipView(text: String) -> some View {
        Text(text)
            .scaledFont(size: 13, weight: .semibold)
            .foregroundStyle(orbitTheme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(orbitTheme.primary.opacity(0.12), in: .capsule)
    }

    private func typingProgress(at elapsed: TimeInterval) -> CGFloat {
        let start: TimeInterval = 0.4
        let duration: TimeInterval = 1.6
        let raw = (elapsed - start) / duration
        return CGFloat(max(0, min(1, raw)))
    }

    private func sparkleProgress(at elapsed: TimeInterval) -> CGFloat {
        let start: TimeInterval = 2.15
        let duration: TimeInterval = 0.4
        let raw = (elapsed - start) / duration
        return CGFloat(max(0, min(1, raw)))
    }

    private func chipProgress(at elapsed: TimeInterval, delay: TimeInterval) -> CGFloat {
        let duration: TimeInterval = 0.35
        let raw = (elapsed - delay) / duration
        return CGFloat(max(0, min(1, raw)))
    }
}

// MARK: - WelcomeMotif

/// Three placeholder memory cards arranged in a loose stack, each gently
/// bobbing on its own delay so the group reads as alive rather than
/// static. Doesn't reveal the *content* of the three welcome-seed
/// memories — that's a small discovery the user gets on Home a moment
/// later. Just signals "your timeline is populated and waiting."
///
/// Respects `accessibilityReduceMotion` — the bob loop is skipped and
/// the cards render statically.
private struct WelcomeMotif: View {
    @Environment(\.orbitTheme) private var orbitTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    /// (xOffset, yOffset, rotation) per card. Picked by eye so the three
    /// silhouettes feel deliberately arranged, not stacked.
    private let layouts: [(CGFloat, CGFloat, Double)] = [
        (-80, -55, -4),
        ( 10,   0,  3),
        (-30,  62, -1.5)
    ]

    var body: some View {
        ZStack {
            ForEach(layouts.indices, id: \.self) { index in
                placeholderCard(index: index)
            }
        }
        .onAppear { bob = true }
    }

    private func placeholderCard(index: Int) -> some View {
        let layout = layouts[index]
        let bobOffset: CGFloat = bob && !reduceMotion ? 4 : 0
        let delay = Double(index) * 0.25
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Capsule().fill(orbitTheme.primary).frame(width: 24, height: 3)
                Capsule().fill(OrbitColor.textTertiary.opacity(0.5)).frame(width: 32, height: 3)
            }
            Capsule().fill(OrbitColor.textPrimary.opacity(0.85)).frame(height: 8)
            Capsule().fill(OrbitColor.textPrimary.opacity(0.6)).frame(width: 100, height: 8)
            Capsule().fill(OrbitColor.textPrimary.opacity(0.35)).frame(width: 70, height: 7)
        }
        .padding(OrbitSpacing.md)
        .frame(width: 180, height: 95, alignment: .leading)
        .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: OrbitRadius.md)
                .stroke(OrbitColor.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        .rotationEffect(.degrees(layout.2))
        .offset(x: layout.0, y: layout.1 + bobOffset)
        .animation(
            reduceMotion
                ? .default
                : .easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(delay),
            value: bob
        )
    }
}
