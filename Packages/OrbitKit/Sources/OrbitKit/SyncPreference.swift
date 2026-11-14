import Foundation

/// The user's iCloud sync choice.
///
/// Orbit 1.x never synced, so 2.0 asks once (What's New for existing users,
/// right after onboarding for new ones) instead of silently uploading a
/// library people believed was on-device. Until they answer, the store stays
/// local-only exactly as before.
public enum SyncPreference: String, Sendable, CaseIterable {
    case undecided
    case on
    case off

    /// Stored in the App Group so the Share Extension and widgets read the
    /// same answer as the app.
    private static let key = "orbit.sync.iCloud"

    public static func load(appGroupIdentifier: String) -> SyncPreference {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        return defaults.string(forKey: key).flatMap(SyncPreference.init(rawValue:)) ?? .undecided
    }

    public func save(appGroupIdentifier: String) {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        defaults.set(rawValue, forKey: Self.key)
    }
}
