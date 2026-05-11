import Speech

public enum SpeechPermission {
    public enum Status: Sendable {
        case undetermined
        case denied
        case restricted
        case granted
    }

    public static var current: Status {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: return .undetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorized:    return .granted
        @unknown default:    return .denied
        }
    }

    public static func request() async -> Status {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .notDetermined: continuation.resume(returning: .undetermined)
                case .denied:        continuation.resume(returning: .denied)
                case .restricted:    continuation.resume(returning: .restricted)
                case .authorized:    continuation.resume(returning: .granted)
                @unknown default:    continuation.resume(returning: .denied)
                }
            }
        }
    }
}
