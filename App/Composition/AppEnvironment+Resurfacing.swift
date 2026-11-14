import Foundation
import OrbitKit
import OrbitDomain

/// The opt-in daily "Worth remembering" notification: one older memory a
/// day, quiet (passive, no sound), so it's a gentle nudge rather than an
/// interruption.
extension AppEnvironment {
    private enum Resurfacing {
        /// Morning, when a small reminder of the past lands best.
        static let hour = 9
        /// Days planned ahead. Notification content is fixed when scheduled,
        /// so the plan is refreshed on every launch.
        static let daysAhead = 7
    }

    /// Turns the daily notification on or off from Settings.
    func setResurfacingEnabled(_ enabled: Bool) async {
        let isOn = await notifications.setResurfacingEnabled(enabled)
        if isOn { await refreshResurfacing() }
    }

    /// Re-plans the next week of resurfacing notifications.
    func refreshResurfacing() async {
        guard notifications.isResurfacingEnabled,
              let memories = try? await memories.list(filter: .all)
        else { return }

        let calendar = Calendar.current
        let now = clock.now()
        let today = calendar.startOfDay(for: now)
        let days: [Date] = (0..<Resurfacing.daysAhead).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: Resurfacing.hour, minute: 0, second: 0, of: day),
                  fire > now
            else { return nil }
            return fire
        }
        var rng = SystemRandomNumberGenerator()
        let picks = ResurfacingPicker().pick(from: memories, for: days, now: now, calendar: calendar, using: &rng)
        await notifications.scheduleResurfacing(picks.map {
            NotificationService.ResurfacingItem(
                memoryID: $0.memory.id,
                preview: ResurfacingPicker.previewText(for: $0.memory),
                fireDate: $0.day
            )
        })
    }
}
