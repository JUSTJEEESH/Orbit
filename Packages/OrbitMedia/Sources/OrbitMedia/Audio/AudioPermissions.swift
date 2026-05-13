import AVFoundation

public enum AudioPermission {
    public enum Status: Sendable {
        case undetermined
        case denied
        case granted
    }

    public static var current: Status {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: return .undetermined
        case .denied:       return .denied
        case .granted:      return .granted
        @unknown default:   return .denied
        }
    }

    public static func request() async -> Status {
        let granted = await AVAudioApplication.requestRecordPermission()
        return granted ? .granted : .denied
    }
}
