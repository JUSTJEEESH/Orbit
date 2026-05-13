import Foundation
import Observation
import SwiftUI

/// Identifies a single soft-gated feature surface. Each case maps to one
/// place in the app where the free tier hits a quota or ceiling; the
/// view layer reads `ProGateService.canAccess(_:)` to decide whether to
/// render the feature normally or present the soft paywall sheet.
///
/// Counted gates (recap, ask) track per-ISO-week usage in
/// UserDefaults. Boolean gates (voice length, year in review, themes)
/// just check Pro status.
public enum ProGate: String, Sendable, CaseIterable, Identifiable {
    case dailyRecap     = "dailyRecap"
    case askOrbit       = "askOrbit"
    case voiceLength    = "voiceLength"
    case yearInReview   = "yearInReview"
    case themes         = "themes"

    public var id: String { rawValue }

    /// Short identifier shown as the eyebrow on the soft-gate sheet.
    public var label: String {
        switch self {
        case .dailyRecap:    return "Daily Recap"
        case .askOrbit:      return "Ask Orbit"
        case .voiceLength:   return "Long-form voice"
        case .yearInReview:  return "Year in Review"
        case .themes:        return "Themes & icons"
        }
    }

    /// SF Symbol that fronts the soft-gate sheet. Each gate gets a
    /// glyph the user already associates with that feature surface.
    public var systemImage: String {
        switch self {
        case .dailyRecap:    return "calendar.badge.clock"
        case .askOrbit:      return "sparkle"
        case .voiceLength:   return "waveform"
        case .yearInReview:  return "calendar"
        case .themes:        return "paintpalette"
        }
    }

    /// Celebratory headline. We intentionally lead with what the user
    /// has done — "You've savored…" rather than "You've reached your
    /// limit." Loss-aversion framing turns into 1-star reviews.
    public var celebratoryHeadline: String {
        switch self {
        case .dailyRecap:
            return "You've savored your free recaps for the week."
        case .askOrbit:
            return "You've asked Orbit a lot this week."
        case .voiceLength:
            return "You've got a lot to say."
        case .yearInReview:
            return "Your year is bigger than the preview."
        case .themes:
            return "Make Orbit feel like yours."
        }
    }

    /// Single-sentence pitch describing what Pro unlocks for this gate.
    /// Keep it concrete — "every day" not "more recaps."
    public var supportingCopy: String {
        switch self {
        case .dailyRecap:
            return "Orbit Pro brings a fresh recap every day, not just three a week."
        case .askOrbit:
            return "Orbit Pro lifts the weekly cap — ask anything, anytime."
        case .voiceLength:
            return "Free voice notes are up to 60 seconds. Pro records up to an hour per note."
        case .yearInReview:
            return "Pro unlocks the full editorial Year in Review: monthly chart, highlights, memory rain."
        case .themes:
            return "Pro unlocks Sunset, Cosmic, and Forest themes — and the matching home-screen icons."
        }
    }
}

/// Tracks the user's free-tier usage and answers the question features
/// need to ask: "can this user do this right now?" The actual gating
/// decisions are colocated here so individual features don't reinvent
/// quota math.
@MainActor
@Observable
public final class ProGateService {
    /// Free-tier quotas. Edited deliberately here so the limits are
    /// visible in one place during App Store review and pricing
    /// experiments.
    public static let freeRecapsPerWeek = 3
    public static let freeAsksPerWeek   = 10
    public static let freeVoiceSeconds: TimeInterval = 60

    private let entitlements: EntitlementService
    private let defaults: UserDefaults
    private let now: @MainActor () -> Date

    public init(
        entitlements: EntitlementService,
        defaults: UserDefaults = .standard,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.entitlements = entitlements
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Public API

    /// Returns true when the user may proceed with the gated action.
    /// Pro short-circuits to true; free users get a per-gate check.
    public func canAccess(_ gate: ProGate) -> Bool {
        if entitlements.state.isPro { return true }
        switch gate {
        case .dailyRecap:
            return weeklyUsage(.dailyRecap) < Self.freeRecapsPerWeek
        case .askOrbit:
            return weeklyUsage(.askOrbit) < Self.freeAsksPerWeek
        case .voiceLength, .yearInReview, .themes:
            // Pure boolean gates — free users see a preview / shortened
            // experience instead of "you've used X of Y."
            return false
        }
    }

    /// Bumps the weekly counter for counted gates. No-op for Pro users
    /// and for boolean gates. Safe to call every time the feature runs.
    public func recordUsage(_ gate: ProGate) {
        guard !entitlements.state.isPro else { return }
        guard Self.countedGates.contains(gate) else { return }
        let key = weekKey(for: gate)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Remaining uses this ISO week for counted gates. nil for boolean
    /// gates and Pro users.
    public func remaining(_ gate: ProGate) -> Int? {
        guard !entitlements.state.isPro else { return nil }
        switch gate {
        case .dailyRecap:
            return max(0, Self.freeRecapsPerWeek - weeklyUsage(.dailyRecap))
        case .askOrbit:
            return max(0, Self.freeAsksPerWeek - weeklyUsage(.askOrbit))
        case .voiceLength, .yearInReview, .themes:
            return nil
        }
    }

    // MARK: - Internals

    private static let countedGates: Set<ProGate> = [.dailyRecap, .askOrbit]

    private func weeklyUsage(_ gate: ProGate) -> Int {
        defaults.integer(forKey: weekKey(for: gate))
    }

    /// Bucket key for the ISO week containing `now()`. Using
    /// `yearForWeekOfYear` (not the regular calendar year) keeps the
    /// week boundary stable when a year flips mid-week.
    private func weekKey(for gate: ProGate) -> String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now())
        return "orbit.gate.\(gate.rawValue).w\(comps.yearForWeekOfYear ?? 0).\(comps.weekOfYear ?? 0)"
    }
}

// MARK: - SwiftUI environment

private struct ProGateServiceKey: EnvironmentKey {
    static let defaultValue: ProGateService? = nil
}

public extension EnvironmentValues {
    /// Optional so previews and tests don't need to construct a service
    /// to compile. Production paths inject it at the app root.
    var proGates: ProGateService? {
        get { self[ProGateServiceKey.self] }
        set { self[ProGateServiceKey.self] = newValue }
    }
}
