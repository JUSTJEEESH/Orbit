import Foundation
import OrbitDomain

/// `PromiseDismissalStore` backed by UserDefaults, as a list of UUID
/// strings. Also used, under its own key, for dismissed place and person
/// reminder suggestions — the same "never suggest this ID again" need.
/// Capped so years of dismissals can't grow the plist unbounded; the
/// oldest drop first, and those memories are long out of view by then.
public final class UserDefaultsPromiseDismissalStore: PromiseDismissalStore, @unchecked Sendable {
    public static let promisesKey = "orbit.promises.dismissed"
    public static let cuesKey = "orbit.cues.dismissed"
    private static let capacity = 1_000

    private let defaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, storageKey: String = UserDefaultsPromiseDismissalStore.promisesKey) {
        self.defaults = defaults
        self.storageKey = storageKey
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
        defaults.set(ids, forKey: storageKey)
    }

    private func stored() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }
}
