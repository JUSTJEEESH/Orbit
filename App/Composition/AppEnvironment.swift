import SwiftUI
import OrbitKit
import OrbitDomain

/// The app-wide environment values used by feature views. We register only
/// what's needed today — the container grows phase by phase as repositories
/// and services come online.
@MainActor
@Observable
final class AppEnvironment {
    let appConfig: AppConfig
    let clock: any OrbitClock

    init(appConfig: AppConfig, clock: any OrbitClock = SystemClock()) {
        self.appConfig = appConfig
        self.clock = clock
    }
}
