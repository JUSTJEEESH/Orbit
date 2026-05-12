import Foundation
import AVFoundation
import EventKit
import Speech
import Photos
import UserNotifications
import Observation

/// Drives the four runtime permission requests Orbit needs. Centralized so
/// onboarding can present a single "permissions" panel and Settings can
/// surface the same statuses later.
///
/// Every grant/deny is observed through the framework's own status APIs,
/// which means we don't track our own state — the system is the source of
/// truth. We just refresh and publish it.
@MainActor
@Observable
public final class PermissionsCoordinator {
    public enum Status: Equatable, Sendable {
        case notDetermined
        case granted
        case denied
        case provisional

        public var isAllowed: Bool {
            self == .granted || self == .provisional
        }
    }

    public enum Permission: String, CaseIterable, Sendable {
        case microphone
        case speechRecognition
        case photos
        case notifications
        case reminders

        public var title: String {
            switch self {
            case .microphone:        return "Microphone"
            case .speechRecognition: return "Speech Recognition"
            case .photos:            return "Photos"
            case .notifications:     return "Notifications"
            case .reminders:         return "Reminders"
            }
        }

        public var systemImage: String {
            switch self {
            case .microphone:        return "mic.fill"
            case .speechRecognition: return "waveform"
            case .photos:            return "photo.fill"
            case .notifications:     return "bell.fill"
            case .reminders:         return "checklist"
            }
        }

        public var rationale: String {
            switch self {
            case .microphone:
                return "Record voice notes the moment a thought hits."
            case .speechRecognition:
                return "Turn voice into text on-device, so notes become searchable."
            case .photos:
                return "Save screenshots and photos as memories."
            case .notifications:
                return "A gentle nudge to revisit your day with Daily Recap."
            case .reminders:
                return "Mirror your tasks to iOS Reminders — manage them from Siri, CarPlay, or the Reminders app."
            }
        }
    }

    public private(set) var statuses: [Permission: Status] = [:]

    public init() {
        for permission in Permission.allCases {
            statuses[permission] = .notDetermined
        }
    }

    public func status(for permission: Permission) -> Status {
        statuses[permission] ?? .notDetermined
    }

    /// Refreshes every permission from its system source of truth. Cheap to
    /// call — none of these are async APIs (notifications excepted).
    public func refreshAll() async {
        statuses[.microphone]        = currentMicrophoneStatus()
        statuses[.speechRecognition] = currentSpeechStatus()
        statuses[.photos]            = currentPhotosStatus()
        statuses[.notifications]     = await currentNotificationsStatus()
        statuses[.reminders]         = currentRemindersStatus()
    }

    /// Triggers the system prompt for a single permission and updates the
    /// observed status from the framework once it resolves.
    @discardableResult
    public func request(_ permission: Permission) async -> Status {
        switch permission {
        case .microphone:        return await requestMicrophone()
        case .speechRecognition: return await requestSpeech()
        case .photos:            return await requestPhotos()
        case .notifications:     return await requestNotifications()
        case .reminders:         return await requestReminders()
        }
    }

    /// Lets callers update the cached status without rerunning the system
    /// prompt. Useful when a downstream service (e.g. RemindersSyncService)
    /// has already invoked the EventKit dialog and we want the coordinator's
    /// UI to reflect the outcome.
    public func setStatus(_ status: Status, for permission: Permission) {
        statuses[permission] = status
    }

    // MARK: - Microphone

    private func currentMicrophoneStatus() -> Status {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: return .notDetermined
        case .granted:      return .granted
        case .denied:       return .denied
        @unknown default:   return .notDetermined
        }
    }

    private func requestMicrophone() async -> Status {
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        let status: Status = granted ? .granted : .denied
        statuses[.microphone] = status
        return status
    }

    // MARK: - Speech recognition

    private func currentSpeechStatus() -> Status {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .notDetermined
        case .authorized:    return .granted
        case .denied:        return .denied
        case .restricted:    return .denied
        @unknown default:    return .notDetermined
        }
    }

    private func requestSpeech() async -> Status {
        let raw = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        let status: Status
        switch raw {
        case .authorized:                       status = .granted
        case .denied, .restricted:              status = .denied
        case .notDetermined:                    status = .notDetermined
        @unknown default:                       status = .notDetermined
        }
        statuses[.speechRecognition] = status
        return status
    }

    // MARK: - Photos

    private func currentPhotosStatus() -> Status {
        // Use the .readWrite level — the capture flow needs to read library
        // photos, never writes, but `.addOnly` doesn't grant read.
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .notDetermined
        }
    }

    private func requestPhotos() async -> Status {
        let raw = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let status: Status
        switch raw {
        case .authorized, .limited: status = .granted
        case .denied, .restricted:  status = .denied
        case .notDetermined:        status = .notDetermined
        @unknown default:           status = .notDetermined
        }
        statuses[.photos] = status
        return status
    }

    // MARK: - Notifications

    private func currentNotificationsStatus() async -> Status {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized:    return .granted
        case .provisional:   return .provisional
        case .denied:        return .denied
        case .ephemeral:     return .granted
        @unknown default:    return .notDetermined
        }
    }

    private func requestNotifications() async -> Status {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            let status: Status = granted ? .granted : .denied
            statuses[.notifications] = status
            return status
        } catch {
            statuses[.notifications] = .denied
            return .denied
        }
    }

    // MARK: - Reminders

    private func currentRemindersStatus() -> Status {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:    return .granted
        case .writeOnly:     return .granted
        case .denied:        return .denied
        case .restricted:    return .denied
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    /// Default Reminders request — purely an EventKit permission prompt.
    /// Onboarding overrides this path through a closure that *also*
    /// flips Orbit's own sync toggle on, so the user gets one-tap
    /// "permission + enable" instead of two separate steps.
    private func requestReminders() async -> Status {
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToReminders()
            let status: Status = granted ? .granted : .denied
            statuses[.reminders] = status
            return status
        } catch {
            statuses[.reminders] = .denied
            return .denied
        }
    }
}
