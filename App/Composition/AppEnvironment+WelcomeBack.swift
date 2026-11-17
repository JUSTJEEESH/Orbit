import Foundation
import OrbitDomain
import OrbitKit
import os

/// Tracks the last time Orbit was opened so Home can say "Welcome back"
/// after a break, instead of anything resembling a broken streak.
extension AppEnvironment {
    private enum WelcomeBackKeys {
        static let lastVisit = "orbit.welcomeBack.lastVisit"
    }

    /// Called at launch and each time the app comes to the foreground.
    /// Reads the previous visit, decides whether to welcome, then records
    /// this visit — so the card appears once per return, not every launch.
    func noteVisit() async {
        let defaults = UserDefaults.standard
        let now = clock.now()
        let previous = defaults.object(forKey: WelcomeBackKeys.lastVisit) as? Date
        defaults.set(now, forKey: WelcomeBackKeys.lastVisit)
        do {
            if let welcome = try await loadWelcomeBack(lastVisit: previous, now: now) {
                welcomeBack = welcome
            }
        } catch {
            OrbitLog.app.error("Welcome back load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func dismissWelcomeBack() {
        welcomeBack = nil
    }
}
