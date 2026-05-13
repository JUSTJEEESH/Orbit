import Foundation
import Observation
import SwiftUI

/// Decides if and when to ask the user to leave an App Store review.
///
/// Apple caps `RequestReviewAction` (and `SKStoreReviewController`) at
/// 3 prompts per 365 days, so the budget is precious. Burning it at
/// launch — or right after an error, or before the user has done
/// anything meaningful — turns a one-time persuasive moment into noise.
/// This service tracks "value moments" (the user just saw a Daily
/// Recap, finished a Year in Review, etc.) and only authorizes a
/// prompt when the user has experienced enough of them, far enough
/// from install and from the previous prompt.
///
/// Persistence lives in `UserDefaults`; the data is small (a handful
/// of dates and integers) and explicitly safe to lose on reinstall.
@MainActor
@Observable
public final class ReviewPromptService {
    public enum ValueEvent: String, Sendable, CaseIterable {
        case dailyRecapViewed
        case yearInReviewCompleted
    }

    private let defaults: UserDefaults
    private let now: @MainActor () -> Date

    // Keys are namespaced so they survive alongside other Orbit prefs.
    private static let installDateKey   = "orbit.review.installedAt"
    private static let lastPromptKey    = "orbit.review.lastPromptedAt"
    private static let lifetimeCountKey = "orbit.review.lifetimeCount"
    private static func eventCountKey(_ event: ValueEvent) -> String {
        "orbit.review.event.\(event.rawValue).count"
    }

    /// Earliest moment we'll consider prompting at all. Sub-48h users
    /// haven't built any feeling about the app yet; a prompt now reads
    /// as desperate.
    private let minimumInstallAge: TimeInterval = 48 * 60 * 60
    /// Quiet period between prompts, used to spread the 3/year budget.
    private let cooldown: TimeInterval = 90 * 24 * 60 * 60
    /// Apple enforces a 3/365 ceiling at the system level; we mirror
    /// it client-side so we don't waste cycles calling into iOS for
    /// requests we know will be no-ops.
    private let lifetimeCap: Int = 3

    public init(
        defaults: UserDefaults = .standard,
        now: @escaping @MainActor () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now
        // Anchor the install date the first time the service is
        // constructed. Re-installs reset this — that's intentional;
        // a fresh install genuinely is a new user-journey starting point.
        if defaults.object(forKey: Self.installDateKey) == nil {
            defaults.set(now(), forKey: Self.installDateKey)
        }
    }

    // MARK: - Recording

    public func recordValueEvent(_ event: ValueEvent) {
        let key = Self.eventCountKey(event)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    public func didRequestReview() {
        defaults.set(now(), forKey: Self.lastPromptKey)
        defaults.set(defaults.integer(forKey: Self.lifetimeCountKey) + 1, forKey: Self.lifetimeCountKey)
    }

    // MARK: - Gating

    /// Returns `true` when every prerequisite is satisfied: enough
    /// lifetime value events of the given kind have been recorded,
    /// the user has lived with the app long enough, prior prompts are
    /// outside the cooldown window, and the lifetime cap isn't hit.
    public func shouldRequestReview(for event: ValueEvent) -> Bool {
        let count = defaults.integer(forKey: Self.eventCountKey(event))
        guard count >= minimumEvents(for: event) else { return false }
        guard installAge >= minimumInstallAge else { return false }
        guard defaults.integer(forKey: Self.lifetimeCountKey) < lifetimeCap else { return false }
        if let last = defaults.object(forKey: Self.lastPromptKey) as? Date {
            guard now().timeIntervalSince(last) >= cooldown else { return false }
        }
        return true
    }

    /// How many of a given event we want to see before that event is
    /// allowed to trigger a prompt. Recaps need to feel routine before
    /// we ask; Year in Review is a single signature moment so one is
    /// enough.
    private func minimumEvents(for event: ValueEvent) -> Int {
        switch event {
        case .dailyRecapViewed:       return 3
        case .yearInReviewCompleted:  return 1
        }
    }

    private var installAge: TimeInterval {
        guard let installedAt = defaults.object(forKey: Self.installDateKey) as? Date else {
            return 0
        }
        return now().timeIntervalSince(installedAt)
    }
}

// MARK: - SwiftUI environment

private struct ReviewPromptServiceKey: EnvironmentKey {
    static let defaultValue: ReviewPromptService? = nil
}

public extension EnvironmentValues {
    /// Optional so previews and tests don't need to construct a service
    /// to compile. Production paths inject it at the app root.
    var reviewPrompts: ReviewPromptService? {
        get { self[ReviewPromptServiceKey.self] }
        set { self[ReviewPromptServiceKey.self] = newValue }
    }
}
