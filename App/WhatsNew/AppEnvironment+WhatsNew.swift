import Foundation
import OrbitKit

/// When to show What's New. Existing users see it once after updating to
/// 2.0; new users get its short form (the iCloud question) right after
/// onboarding. Neither ever sees it twice.
extension AppEnvironment {
    private static let whatsNewSeenKey = "orbit.whatsNew.seenRelease"
    /// Bump to show What's New again for a future release.
    static let whatsNewRelease = "2.0"

    var shouldPresentWhatsNew: Bool {
        onboardingComplete
            && UserDefaults.standard.string(forKey: Self.whatsNewSeenKey) != Self.whatsNewRelease
    }

    /// Someone who was already onboarded when this launch began is an
    /// existing user who just updated; otherwise they onboarded just now.
    var whatsNewAudience: WhatsNewView.Audience {
        wasOnboardedAtLaunch ? .existingUser : .newUser
    }

    func markWhatsNewSeen() {
        UserDefaults.standard.set(Self.whatsNewRelease, forKey: Self.whatsNewSeenKey)
    }
}
