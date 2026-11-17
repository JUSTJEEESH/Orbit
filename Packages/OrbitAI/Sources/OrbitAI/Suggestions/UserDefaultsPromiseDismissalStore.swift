import Foundation
import OrbitDomain

/// `PromiseDismissalStore` backed by UserDefaults, as a list of UUID
/// strings. Capped so years of dismissals can't grow the plist unbounded;
/// the oldest drop first, and those memories are long out of view by then.
public final class UserDefaultsPromiseDismissalStore: PromiseDismissalStore, @unchecked Sendable {
    private static let storageKey = "orbit.promises.dismissed"
    private static let capacity = 1_000

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func dismissedIDs() -> Set<UUID> {
        lock.lock(); defer { lock.unlock() }
        return Set(stored().compactMap(UUID.init(uuidString:)))
    }

    public func dismiss(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var ids = stored()
        guard !ids.contains(id.uuidString) else { return }
        ids.append(id.uuidString)
        if ids.count > Self.capacity { ids.removeFirst(ids.count - Self.capacity) }
        defaults.set(ids, forKey: Self.storageKey)
    }

    private func stored() -> [String] {
        defaults.stringArray(forKey: Self.storageKey) ?? []
    }
}
