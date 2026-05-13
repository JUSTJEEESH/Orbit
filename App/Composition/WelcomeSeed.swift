import Foundation
import OrbitDomain
import OrbitKit

/// Production-safe welcome seeder. Plants three short intro memories
/// the first time onboarding completes so the user never lands on a
/// blank shell — Timeline has content, Search has something to find,
/// the Daily Recap has something to recap on day one.
///
/// Each memory goes through the production `captureMemory` use case
/// and is queued for AI enrichment exactly the way real captures are,
/// so the user immediately sees tags + categories on their first
/// memories. The copy is deliberately easy to recognize as intro
/// content so users feel comfortable swiping them away once they've
/// captured a few of their own.
///
/// Separate from the DEBUG-only `DemoSeed.swift` (which is for
/// screenshot prep and plants ~10 highly specific memories).
extension AppEnvironment {
    private static let welcomeSeededKey = "orbit.welcome.seeded"

    /// Resets the seeded flag so the next onboarding completion
    /// re-plants the welcome memories. Called from the account-wipe
    /// flow — a re-onboarded user deserves the same first-launch
    /// experience as a brand-new install.
    func clearWelcomeSeededFlag() {
        UserDefaults.standard.removeObject(forKey: Self.welcomeSeededKey)
    }

    /// Idempotent. Sets the seeded flag BEFORE writing the first
    /// memory so a crash mid-seed can't repeat the whole seed on the
    /// next launch — at worst the user sees one or two welcome
    /// memories instead of three. Three is the target; one is better
    /// than zero; duplicates are worse than partial coverage.
    @MainActor
    func seedWelcomeMemoriesIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.welcomeSeededKey) else { return }
        defaults.set(true, forKey: Self.welcomeSeededKey)

        await seedWelcomeText("""
            Welcome to Orbit.

            This is your first memory. Anything you capture — text, voice, photos, links — \
            lands here and gets quietly organized.

            Tap the + to add. Open Home for today's recap. Ask Orbit a question to find \
            what you've forgotten.

            When you've added a few of your own, you can delete this one. The rest is yours.
            """)

        await seedWelcomeText("""
            The quiet thought I keep coming back to: most of what's worth remembering \
            doesn't feel important when it happens. The good idea showing up on a walk. \
            The thing a friend said that lands a year later. The book I'm halfway through \
            and would have forgotten without writing it down.

            This is what Orbit is for. The small stuff. The signal you don't notice yet.
            """)

        await seedWelcomeText("""
            A few things to try this week —

            • Capture three thoughts before bed.
            • Record a 30-second voice note on a walk.
            • Open the Daily Recap tomorrow night.
            • Ask Orbit what's on your mind lately.
            """)

        memoriesDidChange()
        OrbitLog.app.notice("Welcome memories seeded.")
    }

    @MainActor
    private func seedWelcomeText(_ body: String) async {
        do {
            let memory = try await captureMemory(content: .text(body))
            scheduleEnrichment(for: memory.id)
        } catch {
            OrbitLog.app.error("Welcome seed text failed: \(String(describing: error), privacy: .public)")
        }
    }
}
