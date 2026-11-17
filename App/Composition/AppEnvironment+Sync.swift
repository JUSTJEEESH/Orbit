import Foundation
import OrbitKit
import OrbitSettingsFeature
import os

/// Whether the open store is being mirrored to the user's iCloud.
enum SyncStatus: Equatable {
    /// Local-only: the user hasn't turned sync on.
    case off
    /// Mirrored to the private CloudKit database.
    case on
    /// The user turned sync on but iCloud couldn't be used this launch, so
    /// the library opened local-only. Nothing is lost; sync resumes once
    /// iCloud is available.
    case unavailable
}

extension AppEnvironment {
    var syncPreference: SyncPreference {
        SyncPreference.load(appGroupIdentifier: appConfig.appGroupIdentifier)
    }

    /// Records the user's iCloud choice and reopens the library with it.
    /// Turning sync on uploads the existing library; turning it off keeps
    /// every memory on this iPhone and stops further syncing.
    func setSyncPreference(_ preference: SyncPreference) {
        let changesStore = (preference == .on) != (syncPreference == .on)
        preference.save(appGroupIdentifier: appConfig.appGroupIdentifier)
        OrbitLog.sync.notice("iCloud sync preference: \(preference.rawValue, privacy: .public)")
        if changesStore {
            reopenLibrary?()
        }
    }
}

extension AppEnvironment {
    /// Settings' view of sync, combining the choice with what happened.
    var settingsSyncStatus: SettingsSyncState.Status {
        switch syncStatus {
        case .on:          .on
        case .unavailable: .unavailable
        case .off:         syncPreference == .on ? .unavailable : .off
        }
    }
}
