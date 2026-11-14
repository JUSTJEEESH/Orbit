import Foundation
import WidgetKit
import OrbitKit
import OrbitDomain

/// When to suggest adding Orbit's widget: after a few captures (so it's
/// clearly useful), only if no Orbit widget is installed, and never again
/// once dismissed.
extension AppEnvironment {
    private static let widgetNudgeDismissedKey = "orbit.widgetNudge.dismissed"
    private static let widgetNudgeMinimumMemories = 3

    func evaluateWidgetNudge() async {
        guard !UserDefaults.standard.bool(forKey: Self.widgetNudgeDismissedKey),
              let count = try? await memories.count(filter: .all),
              count >= Self.widgetNudgeMinimumMemories,
              let installed = try? await WidgetCenter.shared.currentConfigurations()
        else {
            showsWidgetNudge = false
            return
        }
        showsWidgetNudge = installed.isEmpty
    }

    func dismissWidgetNudge() {
        UserDefaults.standard.set(true, forKey: Self.widgetNudgeDismissedKey)
        showsWidgetNudge = false
    }
}
