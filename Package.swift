// swift-tools-version: 6.0
// Orbit workspace package. All modules live here as products so the app target
// (defined in project.yml / Orbit.xcodeproj) consumes a single local package
// reference and pulls only what each target needs.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "OrbitWorkspace",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "OrbitKit", targets: ["OrbitKit"]),
        .library(name: "OrbitDesignSystem", targets: ["OrbitDesignSystem"]),
        .library(name: "OrbitDomain", targets: ["OrbitDomain"]),
        .library(name: "OrbitPersistence", targets: ["OrbitPersistence"]),
        .library(name: "OrbitHomeFeature", targets: ["OrbitHomeFeature"]),
        .library(name: "OrbitTimelineFeature", targets: ["OrbitTimelineFeature"]),
        .library(name: "OrbitSearchFeature", targets: ["OrbitSearchFeature"]),
        .library(name: "OrbitCaptureFeature", targets: ["OrbitCaptureFeature"]),
        .library(name: "OrbitSettingsFeature", targets: ["OrbitSettingsFeature"]),
    ],
    targets: [
        // MARK: - Cross-cutting
        .target(
            name: "OrbitKit",
            path: "Packages/OrbitKit/Sources/OrbitKit",
            swiftSettings: swiftSettings
        ),

        // MARK: - Design System
        .target(
            name: "OrbitDesignSystem",
            dependencies: ["OrbitKit"],
            path: "Packages/OrbitDesignSystem/Sources/OrbitDesignSystem",
            swiftSettings: swiftSettings
        ),

        // MARK: - Domain (pure Swift, no framework imports)
        .target(
            name: "OrbitDomain",
            path: "Packages/OrbitDomain/Sources/OrbitDomain",
            swiftSettings: swiftSettings
        ),

        // MARK: - Persistence
        .target(
            name: "OrbitPersistence",
            dependencies: ["OrbitDomain"],
            path: "Packages/OrbitPersistence/Sources/OrbitPersistence",
            swiftSettings: swiftSettings
        ),

        // MARK: - Features
        .target(
            name: "OrbitHomeFeature",
            dependencies: ["OrbitKit", "OrbitDesignSystem", "OrbitDomain"],
            path: "Packages/Features/Home/Sources/OrbitHomeFeature",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "OrbitTimelineFeature",
            dependencies: ["OrbitKit", "OrbitDesignSystem", "OrbitDomain"],
            path: "Packages/Features/Timeline/Sources/OrbitTimelineFeature",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "OrbitSearchFeature",
            dependencies: ["OrbitKit", "OrbitDesignSystem", "OrbitDomain"],
            path: "Packages/Features/Search/Sources/OrbitSearchFeature",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "OrbitCaptureFeature",
            dependencies: ["OrbitKit", "OrbitDesignSystem", "OrbitDomain"],
            path: "Packages/Features/Capture/Sources/OrbitCaptureFeature",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "OrbitSettingsFeature",
            dependencies: ["OrbitKit", "OrbitDesignSystem", "OrbitDomain"],
            path: "Packages/Features/Settings/Sources/OrbitSettingsFeature",
            swiftSettings: swiftSettings
        ),

        // MARK: - Tests
        .testTarget(
            name: "OrbitDomainTests",
            dependencies: ["OrbitDomain"],
            path: "Packages/OrbitDomain/Tests/OrbitDomainTests",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OrbitDesignSystemTests",
            dependencies: ["OrbitDesignSystem"],
            path: "Packages/OrbitDesignSystem/Tests/OrbitDesignSystemTests",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OrbitPersistenceTests",
            dependencies: ["OrbitPersistence", "OrbitDomain"],
            path: "Packages/OrbitPersistence/Tests/OrbitPersistenceTests",
            swiftSettings: swiftSettings
        ),
    ]
)
