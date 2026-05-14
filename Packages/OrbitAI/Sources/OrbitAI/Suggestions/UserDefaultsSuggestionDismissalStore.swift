import Foundation
import OrbitDomain

/// `SuggestionDismissalStore` backed by UserDefaults. Stores a single
/// dictionary at `orbit.suggestions.dismissed` keyed by UUID-string and
/// valued by `TimeInterval` (since 1970). Dismissals expire after
/// `dismissalWindow` so a user's old "no" doesn't permanently hide a
/// memory that may become relevant later.
public final class UserDefaultsSuggestionDismissalStore: SuggestionDismissalStore, @unchecked Sendable {
    private static let storageKey = "orbit.suggestions.dismissed"
    /// 90 days. Long enough that the user gets a real break from a
    /// memory they explicitly hid; short enough that interests can
    /// shift back without a permanent blacklist. Tuned by feel; revisit
    /// if dismissal data ever shows people re-dismissing the same
    /// memories repeatedly (would suggest the window is too short).
    private static let dismissalWindow: TimeInterval = 60 * 60 * 24 * 90

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isDismissed(_ memoryID: UUID, at date: Date) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let map = currentMap(), let dismissedAt = map[memoryID.uuidString] else { return false }
        return (date.timeIntervalSince1970 - dismissedAt) < Self.dismissalWindow
    }

    public func dismiss(_ memoryID: UUID, at date: Date) {
        lock.lock(); defer { lock.unlock() }
        var map = currentMap() ?? [:]
        map[memoryID.uuidString] = date.timeIntervalSince1970
        defaults.set(map, forKey: Self.storageKey)
    }

    public func dismissedIDs(at date: Date) -> Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        guard let map = currentMap() else { return [] }
        let cutoff = date.timeIntervalSince1970 - Self.dismissalWindow
        return Set(map.compactMap { (idString, dismissedAt) in
            dismissedAt > cutoff ? UUID(uuidString: idString) : nil
        })
    }

    public func clearAll() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func currentMap() -> [String: TimeInterval]? {
        defaults.dictionary(forKey: Self.storageKey) as? [String: TimeInterval]
    }
}
