import Foundation
import OrbitDomain

/// Persists per-kind dismissals in `UserDefaults` as a `[kindRaw: epochSeconds]`
/// dictionary. Cheap, atomic, and bounded — the dictionary has at most one
/// entry per `SmartInsight.Kind`.
public final class UserDefaultsInsightDismissalStore: InsightDismissalStore, @unchecked Sendable {
    private static let storageKey = "orbit.insights.dismissals"
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isDismissed(_ kind: SmartInsight.Kind, now: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let map = currentMap()
        guard let until = map[kind.rawValue] else { return false }
        return until > now.timeIntervalSince1970
    }

    public func dismiss(_ kind: SmartInsight.Kind, until: Date) {
        lock.lock(); defer { lock.unlock() }
        var map = currentMap()
        map[kind.rawValue] = until.timeIntervalSince1970
        defaults.set(map, forKey: Self.storageKey)
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func currentMap() -> [String: TimeInterval] {
        (defaults.dictionary(forKey: Self.storageKey) as? [String: TimeInterval]) ?? [:]
    }
}
