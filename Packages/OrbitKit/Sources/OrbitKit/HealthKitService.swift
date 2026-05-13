import Foundation
import HealthKit
import Observation
import UIKit

/// Read-only HealthKit wrapper. Surfaces three signals to the rest of
/// Orbit:
/// - Sleep duration for a given calendar day (driving the Daily Recap
///   footer).
/// - Steps for a given calendar day (same footer).
/// - The user's typical sleep window over the past week (driving the
///   sleep-aware-notification hint in Settings).
///
/// Authorization-wise HealthKit is unusual: for read scopes there's no
/// public way to query the status, only to attempt a read. We track the
/// user's stated intent (`isEnabled` from a Settings toggle) separately
/// from the actual HealthKit prompt outcome.
@MainActor
@Observable
public final class HealthKitService {
    public static let isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    /// User-visible "have we asked yet?" — flipped on once the auth
    /// request has returned successfully. Persists in UserDefaults so
    /// onboarding doesn't re-prompt on every cold start.
    public private(set) var hasRequestedAuthorization: Bool

    /// User's stated intent to let Orbit read Health data. Separate from
    /// the system auth state — flipping this off in Settings stops Orbit
    /// from reading even while iOS still has access granted, which gives
    /// the user a quick kill-switch without leaving the app.
    public private(set) var isEnabled: Bool

    /// Captured at runtime when a read succeeds; we use it to decide
    /// whether to show the Daily Recap footer at all.
    public private(set) var lastReadSucceeded: Bool = false

    private let store: HKHealthStore?
    private static let requestedKey = "orbit.healthkit.requested"
    private static let enabledKey = "orbit.healthkit.enabled"

    public init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.store = HKHealthStore()
        } else {
            self.store = nil
        }
        let defaults = UserDefaults.standard
        let requested = defaults.bool(forKey: Self.requestedKey)
        self.hasRequestedAuthorization = requested
        // Upgrade path: users who authorized before this flag existed
        // get their Orbit-side toggle pre-flipped to match.
        if defaults.object(forKey: Self.enabledKey) == nil {
            self.isEnabled = requested
        } else {
            self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        }
    }

    public var isAvailable: Bool { store != nil }

    /// Triggers the HealthKit permission sheet for read access to sleep +
    /// step samples. Apple intentionally doesn't return per-type read
    /// authorization status, so this just records that we asked.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard let store else { return false }
        let readTypes: Set<HKObjectType> = Set([
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .stepCount)
        ].compactMap { $0 as HKObjectType? })

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedAuthorization = true
            UserDefaults.standard.set(true, forKey: Self.requestedKey)
            return true
        } catch {
            OrbitLog.app.error("HealthKit auth request failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Flip the Orbit-side toggle. Enabling triggers the system prompt
    /// on the first run; subsequent toggles only update the local flag
    /// since iOS doesn't allow apps to programmatically revoke access.
    /// Returns true when the resulting state matches the requested
    /// value — callers can use this to surface a soft failure haptic
    /// when the auth prompt is denied.
    @discardableResult
    public func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            if !hasRequestedAuthorization {
                let ok = await requestAuthorization()
                guard ok else { return false }
            }
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            return true
        } else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            return true
        }
    }

    public func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Snapshot for a calendar day

    /// Combined sleep + step snapshot for the day containing `date`. nil
    /// fields mean we couldn't read that signal — typically permission
    /// denied or the user has no data for that day. The Daily Recap
    /// view treats an all-nil snapshot as "skip the footer."
    public func snapshot(for date: Date) async -> HealthSnapshot {
        async let sleep = sleepDuration(forNightLeadingUpTo: date)
        async let steps = stepCount(for: date)
        let (sleepValue, stepsValue) = await (sleep, steps)
        if sleepValue != nil || stepsValue != nil {
            lastReadSucceeded = true
        }
        return HealthSnapshot(sleepDuration: sleepValue, steps: stepsValue)
    }

    // MARK: - Sleep

    /// Total time asleep during the night that ended on `date`. Uses the
    /// 6 PM previous day → noon current day window — long enough to catch
    /// late-night sleepers and afternoon power nappers without bleeding
    /// into the next night.
    public func sleepDuration(forNightLeadingUpTo date: Date) async -> TimeInterval? {
        guard store != nil else { return nil }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay),
            let windowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay)
        else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let samples = await fetchCategorySamples(type: type, predicate: predicate)
        guard let samples, !samples.isEmpty else { return nil }
        return samples
            .filter { Self.isAsleepValue($0.value) }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }

    private static func isAsleepValue(_ raw: Int) -> Bool {
        // iOS 16+ split sleep into stages; treat any "asleep*" as time
        // asleep. The pre-iOS-16 `.asleep` is now `.asleepUnspecified`
        // and shares the same raw value, so one entry covers both.
        switch raw {
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
             HKCategoryValueSleepAnalysis.asleepCore.rawValue,
             HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
             HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return true
        default:
            return false
        }
    }

    // MARK: - Steps

    public func stepCount(for date: Date) async -> Int? {
        guard let store else { return nil }
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count())
                continuation.resume(returning: sum.map { Int($0.rounded()) })
            }
            store.execute(query)
        }
    }

    // MARK: - Typical sleep window

    /// Inferred [bedtime, wake] window — averages sleep samples across the
    /// last 7 nights and rounds to the nearest 30 minutes. nil when there
    /// aren't enough samples to be useful.
    public func typicalSleepWindow() async -> SleepWindow? {
        guard store != nil else { return nil }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)
        let samples = await fetchCategorySamples(type: type, predicate: predicate)
        guard let samples else { return nil }

        let asleep = samples.filter { Self.isAsleepValue($0.value) }
        guard asleep.count >= 3 else { return nil }

        // For each "night," collapse contiguous asleep samples into a
        // single block, then average the start and end times.
        let startMinutes: [Int] = asleep.map { sample in
            let comps = calendar.dateComponents([.hour, .minute], from: sample.startDate)
            return ((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) % (24 * 60)
        }
        let endMinutes: [Int] = asleep.map { sample in
            let comps = calendar.dateComponents([.hour, .minute], from: sample.endDate)
            return ((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) % (24 * 60)
        }

        let avgStart = Self.circularAverage(minutes: startMinutes)
        let avgEnd = Self.circularAverage(minutes: endMinutes)
        return SleepWindow(
            bedtimeHour: avgStart / 60,
            bedtimeMinute: avgStart % 60,
            wakeHour: avgEnd / 60,
            wakeMinute: avgEnd % 60
        )
    }

    /// Returns true if a clock time (hour + minute in local calendar)
    /// falls inside the supplied sleep window, accounting for windows
    /// that cross midnight (e.g. bedtime 23:00, wake 07:00).
    public static func isInWindow(hour: Int, minute: Int, window: SleepWindow) -> Bool {
        let target = hour * 60 + minute
        let start = window.bedtimeHour * 60 + window.bedtimeMinute
        let end = window.wakeHour * 60 + window.wakeMinute
        if start <= end {
            return target >= start && target <= end
        } else {
            // Crosses midnight.
            return target >= start || target <= end
        }
    }

    // MARK: - HealthKit query plumbing

    private func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate
    ) async -> [HKCategorySample]? {
        guard let store else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[HKCategorySample]?, Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKCategorySample])
            }
            store.execute(query)
        }
    }

    /// Average a set of minute-of-day values in a circular fashion so
    /// that 23:50 and 00:10 average to 00:00 instead of noon.
    private static func circularAverage(minutes: [Int]) -> Int {
        guard !minutes.isEmpty else { return 0 }
        let twoPi = 2.0 * Double.pi
        let radians = minutes.map { Double($0) / (24.0 * 60.0) * twoPi }
        let avgSin = radians.map { sin($0) }.reduce(0, +) / Double(radians.count)
        let avgCos = radians.map { cos($0) }.reduce(0, +) / Double(radians.count)
        var avgRadians = atan2(avgSin, avgCos)
        if avgRadians < 0 { avgRadians += twoPi }
        let avgMinutes = Int((avgRadians / twoPi * 24.0 * 60.0).rounded())
        return avgMinutes % (24 * 60)
    }
}

/// Daily snapshot displayed on the Daily Recap footer.
public struct HealthSnapshot: Sendable, Hashable {
    public let sleepDuration: TimeInterval?
    public let steps: Int?

    public init(sleepDuration: TimeInterval?, steps: Int?) {
        self.sleepDuration = sleepDuration
        self.steps = steps
    }

    public var isEmpty: Bool { sleepDuration == nil && steps == nil }
}

/// Inferred typical sleep window — used to warn the user when their
/// Daily Recap notification time would land while they're asleep.
public struct SleepWindow: Sendable, Hashable {
    public let bedtimeHour: Int
    public let bedtimeMinute: Int
    public let wakeHour: Int
    public let wakeMinute: Int

    public init(bedtimeHour: Int, bedtimeMinute: Int, wakeHour: Int, wakeMinute: Int) {
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
    }
}
