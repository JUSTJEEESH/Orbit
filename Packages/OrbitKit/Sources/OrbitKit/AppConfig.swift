import Foundation

/// Build- and runtime-resolved application configuration. Read-only at app
/// scope; injected via `@Environment` so test surfaces can substitute fakes.
public struct AppConfig: Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let marketingVersion: String
    public let buildNumber: String
    public let environment: Environment
    public let appGroupIdentifier: String
    public let cloudKitContainerIdentifier: String

    public enum Environment: String, Sendable {
        case debug
        case testflight
        case production

        public static var current: Environment {
            #if DEBUG
            return .debug
            #else
            if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                return .testflight
            }
            return .production
            #endif
        }
    }

    public init(
        bundleIdentifier: String,
        displayName: String,
        marketingVersion: String,
        buildNumber: String,
        environment: Environment,
        appGroupIdentifier: String,
        cloudKitContainerIdentifier: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
        self.environment = environment
        self.appGroupIdentifier = appGroupIdentifier
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
    }

    /// Resolved from the main bundle. Call once at app launch from the
    /// composition root, never reach for `.bundle` from feature code.
    public static func resolveFromBundle(
        appGroupIdentifier: String = "group.com.joshgreen.orbit",
        cloudKitContainerIdentifier: String = "iCloud.com.joshgreen.orbit"
    ) -> AppConfig {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppConfig(
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.joshgreen.orbit",
            displayName: info["CFBundleDisplayName"] as? String ?? "Orbit",
            marketingVersion: info["CFBundleShortVersionString"] as? String ?? "0.0.0",
            buildNumber: info["CFBundleVersion"] as? String ?? "0",
            environment: Environment.current,
            appGroupIdentifier: appGroupIdentifier,
            cloudKitContainerIdentifier: cloudKitContainerIdentifier
        )
    }
}
