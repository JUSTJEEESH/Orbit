import SwiftUI
import AuthenticationServices
import OrbitDesignSystem
import OrbitKit
import OrbitAccount
import OrbitStore

public struct SettingsView: View {
    private let appConfig: AppConfig
    @Bindable private var account: AccountService
    @Bindable private var entitlements: EntitlementService
    @Bindable private var notifications: NotificationService
    /// Optional — when supplied, the Notifications section warns the user
    /// if their chosen Daily Recap time falls inside their typical sleep
    /// window. Sourced from HealthKit on appear.
    private let healthKit: HealthKitService?
    @State private var typicalSleepWindow: SleepWindow?
    private let currentTheme: OrbitTheme
    private let onSelectTheme: @MainActor @Sendable (OrbitTheme) async -> Void
    private let iconError: String?
    private let onPresentPaywall: @MainActor () -> Void
    private let onDeleteAccount: @MainActor @Sendable () async throws -> Void
    private let onDismiss: @MainActor () -> Void

    /// Reminders sync state surfaced through plain values so this feature
    /// package doesn't have to depend on EventKit. RootView wires the live
    /// bindings to `RemindersSyncService`.
    private let remindersSyncEnabled: Bool
    private let remindersAuthorized: Bool
    private let remindersDenied: Bool
    private let remindersLastError: String?
    private let onToggleRemindersSync: @MainActor @Sendable (Bool) async -> Void
    private let onOpenRemindersSettings: @MainActor () -> Void

    /// Calendar sync surface — same flattened-binding pattern as
    /// Reminders so the package never imports EventKit. RootView
    /// wires these to `CalendarSyncService`.
    private let calendarSyncEnabled: Bool
    private let calendarAuthorized: Bool
    private let calendarDenied: Bool
    private let calendarLastError: String?
    private let onToggleCalendarSync: @MainActor @Sendable (Bool) async -> Void
    private let onOpenCalendarSettings: @MainActor () -> Void

    @State private var showDeleteConfirmation = false
    @State private var deletionError: String?

    public init(
        appConfig: AppConfig,
        account: AccountService,
        entitlements: EntitlementService,
        notifications: NotificationService,
        currentTheme: OrbitTheme,
        onSelectTheme: @escaping @MainActor @Sendable (OrbitTheme) async -> Void,
        iconError: String? = nil,
        onPresentPaywall: @escaping @MainActor () -> Void,
        onDeleteAccount: @escaping @MainActor @Sendable () async throws -> Void,
        onDismiss: @escaping @MainActor () -> Void,
        remindersSyncEnabled: Bool = false,
        remindersAuthorized: Bool = false,
        remindersDenied: Bool = false,
        remindersLastError: String? = nil,
        onToggleRemindersSync: @escaping @MainActor @Sendable (Bool) async -> Void = { _ in },
        onOpenRemindersSettings: @escaping @MainActor () -> Void = {},
        calendarSyncEnabled: Bool = false,
        calendarAuthorized: Bool = false,
        calendarDenied: Bool = false,
        calendarLastError: String? = nil,
        onToggleCalendarSync: @escaping @MainActor @Sendable (Bool) async -> Void = { _ in },
        onOpenCalendarSettings: @escaping @MainActor () -> Void = {},
        healthKit: HealthKitService? = nil
    ) {
        self.appConfig = appConfig
        self.account = account
        self.entitlements = entitlements
        self.notifications = notifications
        self.currentTheme = currentTheme
        self.onSelectTheme = onSelectTheme
        self.iconError = iconError
        self.onPresentPaywall = onPresentPaywall
        self.onDeleteAccount = onDeleteAccount
        self.onDismiss = onDismiss
        self.remindersSyncEnabled = remindersSyncEnabled
        self.remindersAuthorized = remindersAuthorized
        self.remindersDenied = remindersDenied
        self.remindersLastError = remindersLastError
        self.onToggleRemindersSync = onToggleRemindersSync
        self.onOpenRemindersSettings = onOpenRemindersSettings
        self.calendarSyncEnabled = calendarSyncEnabled
        self.calendarAuthorized = calendarAuthorized
        self.calendarDenied = calendarDenied
        self.calendarLastError = calendarLastError
        self.onToggleCalendarSync = onToggleCalendarSync
        self.onOpenCalendarSettings = onOpenCalendarSettings
        self.healthKit = healthKit
    }

    public var body: some View {
        NavigationStack {
            OrbitScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: OrbitSpacing.xl) {
                        accountSection
                        appearanceSection
                        notificationsSection
                        remindersSection
                        calendarSection
                        subscriptionSection
                        aboutSection
                        dangerSection
                    }
                    .padding(.vertical, OrbitSpacing.lg)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .font(OrbitTypography.bodyEmphasized)
                }
            }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task { @MainActor in
                        do {
                            try await onDeleteAccount()
                            Haptics.play(.success)
                            onDismiss()
                        } catch {
                            deletionError = error.localizedDescription
                            Haptics.play(.failure)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This signs you out and permanently erases every memory on this device. This can't be undone.")
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Account")
            OrbitCard {
                accountCardContent
            }
        }
    }

    @ViewBuilder
    private var accountCardContent: some View {
        switch account.state {
        case .guest:
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guest")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Sign in with Apple to keep your memories yours — backed up to your iCloud, available across your devices.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                signInWithAppleButton
            }

        case .signedIn(let identity):
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.fullName ?? "Signed in")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    if let email = identity.email {
                        Text(email)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.textSecondary)
                    }
                }
                OrbitButton("Sign out", style: .secondary) {
                    account.signOut()
                    Haptics.play(.warning)
                }
            }

        case .revoked:
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple ID changed")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Your previous sign-in is no longer valid. Tap below to sign in again.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                signInWithAppleButton
            }
        }
    }

    /// Sign in with Apple — shared by the `.guest` and `.revoked` rows.
    /// Routes the result through `AccountService.handle(_:)`, which is
    /// the same path Onboarding uses, so the post-sign-in state lands
    /// identically regardless of where the user signed in from.
    private var signInWithAppleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            account.handle(result)
            if case .signedIn = account.state {
                Haptics.play(.success)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 48)
        .clipShape(.rect(cornerRadius: OrbitRadius.md))
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Appearance", subtitle: "Choose the accent that runs through Orbit.")
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: OrbitSpacing.sm),
                    GridItem(.flexible(), spacing: OrbitSpacing.sm),
                ],
                spacing: OrbitSpacing.sm
            ) {
                ForEach(OrbitTheme.all) { theme in
                    themeTile(theme)
                }
            }
            if let iconError {
                Text("Couldn't change the home-screen icon: \(iconError)")
                    .font(OrbitTypography.footnote)
                    .foregroundStyle(OrbitColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func themeTile(_ theme: OrbitTheme) -> some View {
        let isSelected = theme == currentTheme
        return Button {
            Haptics.play(.selection)
            Task { @MainActor in await onSelectTheme(theme) }
        } label: {
            VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(theme.primary)
                        .frame(width: 44, height: 44)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledFont(size: 18, weight: .semibold)
                            .foregroundStyle(OrbitColor.textInverted, theme.primary)
                            .offset(x: 6, y: -6)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text(theme.promotionalCopy)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(OrbitSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OrbitColor.surface, in: .rect(cornerRadius: OrbitRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitRadius.lg)
                    .stroke(
                        isSelected ? theme.primary : OrbitColor.separator,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.name) theme. \(theme.promotionalCopy)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Currently selected." : "Double-tap to switch to this theme.")
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Notifications", subtitle: "A gentle nudge to revisit your day.")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Toggle(isOn: dailyRecapToggleBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Recap")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text("A quiet reminder each evening to reflect.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(currentTheme.primary)

                    if notifications.isEnabled {
                        OrbitDivider()
                        HStack {
                            Text("Time")
                                .font(OrbitTypography.callout)
                                .foregroundStyle(OrbitColor.textSecondary)
                            Spacer()
                            DatePicker(
                                "Time",
                                selection: recapTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                        if let sleepHint = sleepConflictHint {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "moon.stars.fill")
                                    .scaledFont(size: 12, weight: .semibold)
                                    .foregroundStyle(OrbitColor.warning)
                                Text(sleepHint)
                                    .font(OrbitTypography.footnote)
                                    .foregroundStyle(OrbitColor.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if notifications.authorizationStatus == .denied {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                            Text("Notifications are turned off for Orbit in iOS Settings.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.warning)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open iOS Settings") {
                                notifications.openSystemSettings()
                            }
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(currentTheme.primary)
                        }
                    }
                }
            }
        }
        .task {
            await notifications.refreshAuthorizationStatus()
            if let healthKit, healthKit.hasRequestedAuthorization {
                typicalSleepWindow = await healthKit.typicalSleepWindow()
            }
        }
    }

    /// Returns a single warning sentence when the user's chosen Daily
    /// Recap time falls inside their inferred sleep window. Nil when
    /// HealthKit hasn't been authorized, the window can't be computed,
    /// or the time is safely outside it.
    private var sleepConflictHint: String? {
        guard let typicalSleepWindow else { return nil }
        let hour = notifications.time.hour ?? 20
        let minute = notifications.time.minute ?? 0
        guard HealthKitService.isInWindow(hour: hour, minute: minute, window: typicalSleepWindow) else { return nil }
        let wake = String(format: "%d:%02d", typicalSleepWindow.wakeHour, typicalSleepWindow.wakeMinute)
        return "You usually sleep at this hour. Consider moving it past \(wake)."
    }

    private var dailyRecapToggleBinding: Binding<Bool> {
        Binding(
            get: { notifications.isEnabled },
            set: { newValue in
                Task { @MainActor in
                    await notifications.setEnabled(newValue)
                    if newValue, notifications.isEnabled {
                        Haptics.play(.success)
                    } else if newValue, !notifications.isEnabled {
                        // Permission was denied; surface a soft failure.
                        Haptics.play(.warning)
                    }
                }
            }
        )
    }

    private var recapTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: notifications.time)
                    ?? Calendar.current.startOfDay(for: Date())
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                Task { @MainActor in
                    await notifications.setTime(
                        hour: comps.hour ?? 20,
                        minute: comps.minute ?? 0
                    )
                }
            }
        )
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Reminders", subtitle: "Mirror your tasks to the iOS Reminders app.")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Toggle(isOn: remindersSyncToggleBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync with Reminders")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text("Manage Orbit tasks from Siri, CarPlay, or the Reminders app — and watch completions flow back automatically.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(currentTheme.primary)

                    if remindersDenied {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                            Text("Reminders access is turned off for Orbit in iOS Settings.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.warning)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open iOS Settings") {
                                onOpenRemindersSettings()
                            }
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(currentTheme.primary)
                        }
                    } else if let message = remindersLastError {
                        // Surfaces silent failures (e.g. simulator without
                        // an iCloud Reminders list set up) instead of
                        // letting them feel like the toggle is broken.
                        Text(message)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var remindersSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { remindersSyncEnabled },
            set: { newValue in
                Task { @MainActor in
                    await onToggleRemindersSync(newValue)
                    if newValue, !remindersSyncEnabled {
                        // Toggle snapped back: permission denied.
                        Haptics.play(.warning)
                    } else if newValue {
                        Haptics.play(.success)
                    }
                }
            }
        )
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Calendar", subtitle: "Mirror your due-dated tasks to iOS Calendar.")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Toggle(isOn: calendarSyncToggleBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync with Calendar")
                                .font(OrbitTypography.bodyEmphasized)
                                .foregroundStyle(OrbitColor.textPrimary)
                            Text("Tasks with due dates land in a dedicated \u{201C}Orbit\u{201D} calendar — so they show up on the Lock Screen, Apple Watch, and CarPlay alongside your meetings.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(currentTheme.primary)

                    if calendarDenied {
                        VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                            Text("Calendar access is turned off for Orbit in iOS Settings.")
                                .font(OrbitTypography.footnote)
                                .foregroundStyle(OrbitColor.warning)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open iOS Settings") {
                                onOpenCalendarSettings()
                            }
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(currentTheme.primary)
                        }
                    } else if let message = calendarLastError {
                        Text(message)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var calendarSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { calendarSyncEnabled },
            set: { newValue in
                Task { @MainActor in
                    await onToggleCalendarSync(newValue)
                    if newValue, !calendarSyncEnabled {
                        Haptics.play(.warning)
                    } else if newValue {
                        Haptics.play(.success)
                    }
                }
            }
        )
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Subscription")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    HStack(spacing: OrbitSpacing.xs) {
                        Image(systemName: entitlements.state.isPro ? "sparkles" : "lock")
                            .foregroundStyle(entitlements.state.isPro ? OrbitColor.accent : OrbitColor.textSecondary)
                        Text(entitlements.state.isPro ? "Orbit Pro" : "Free")
                            .font(OrbitTypography.bodyEmphasized)
                            .foregroundStyle(OrbitColor.textPrimary)
                        Spacer()
                    }
                    Text(subscriptionDetail)
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !entitlements.state.isPro {
                        OrbitButton("Upgrade to Pro", systemImage: "sparkles", style: .primary) {
                            onPresentPaywall()
                        }
                    } else {
                        OrbitButton("Restore purchases", style: .secondary) {
                            Task { await entitlements.restore() }
                        }
                    }
                }
            }
        }
    }

    private var subscriptionDetail: String {
        switch entitlements.state {
        case .unknown:
            return "Checking your subscription…"
        case .free:
            return "You're on the free plan. Upgrade for unlimited captures, AI organization, and sync."
        case .pro(let expiresAt):
            if let expiresAt {
                return "Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))."
            }
            return "Lifetime plan. Yours forever."
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("Danger zone")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
                    Text("Delete account & data")
                        .font(OrbitTypography.bodyEmphasized)
                        .foregroundStyle(OrbitColor.textPrimary)
                    Text("Sign out and erase every memory on this device. There's no recovery.")
                        .font(OrbitTypography.footnote)
                        .foregroundStyle(OrbitColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let deletionError {
                        Text(deletionError)
                            .font(OrbitTypography.footnote)
                            .foregroundStyle(OrbitColor.danger)
                    }
                    OrbitButton("Delete account", systemImage: "trash", style: .destructive) {
                        Haptics.play(.warning)
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }

    // MARK: - About

    /// Live URLs for the App Store-required legal + support pages.
    /// Hosted on Netlify (orbitbrain2.netlify.app). Apple Review will
    /// fail submission if any of these return 404, so update both
    /// here and the Netlify site together when the domain or routes
    /// change.
    private static let privacyURL = URL(string: "https://orbitbrain2.netlify.app/privacy")!
    private static let termsURL   = URL(string: "https://orbitbrain2.netlify.app/terms")!
    private static let supportURL = URL(string: "https://orbitbrain2.netlify.app/support")!

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: OrbitSpacing.md) {
            OrbitSectionHeader("About")
            OrbitCard {
                VStack(alignment: .leading, spacing: OrbitSpacing.xs) {
                    keyValue("Version", "\(appConfig.marketingVersion) (\(appConfig.buildNumber))")
                    OrbitDivider()
                    linkRow(title: "Privacy Policy", systemImage: "lock.shield", url: Self.privacyURL)
                    OrbitDivider()
                    linkRow(title: "Terms of Use", systemImage: "doc.text", url: Self.termsURL)
                    OrbitDivider()
                    linkRow(title: "Contact Support", systemImage: "envelope", url: Self.supportURL)
                }
            }
        }
    }

    /// Tappable About row that opens an external URL. Uses a chevron
    /// glyph to telegraph the leave-the-app affordance the way iOS
    /// Settings does.
    private func linkRow(title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: OrbitSpacing.sm) {
                Image(systemName: systemImage)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(currentTheme.primary)
                    .frame(width: 24)
                Text(title)
                    .font(OrbitTypography.callout)
                    .foregroundStyle(OrbitColor.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(OrbitColor.textTertiary)
            }
            .padding(.vertical, OrbitSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textSecondary)
            Spacer()
            Text(value)
                .font(OrbitTypography.callout)
                .foregroundStyle(OrbitColor.textPrimary)
        }
        .padding(.vertical, OrbitSpacing.xxs)
    }
}
