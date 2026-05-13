import Foundation
import FoundationModels

/// Friendly snapshot of the on-device Apple Intelligence model state.
/// Designed for surfacing in Settings → Developer so engineers can see at a
/// glance why classification might be falling back to the heuristic path.
public struct SystemModelStatus: Sendable, Equatable {
    public let summary: String
    public let detail: String
    public let isAvailable: Bool

    public init(summary: String, detail: String, isAvailable: Bool) {
        self.summary = summary
        self.detail = detail
        self.isAvailable = isAvailable
    }

    public static func current() -> SystemModelStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return SystemModelStatus(
                summary: "Available",
                detail: "Foundation Models will classify captures on-device.",
                isAvailable: true
            )
        case .unavailable(let reason):
            return Self.statusFor(reason: reason)
        @unknown default:
            return SystemModelStatus(
                summary: "Unknown",
                detail: "Foundation Models reported an unknown availability case.",
                isAvailable: false
            )
        }
    }

    private static func statusFor(
        reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> SystemModelStatus {
        switch reason {
        case .deviceNotEligible:
            return SystemModelStatus(
                summary: "Device not eligible",
                detail: "Apple Intelligence needs an Apple Silicon Mac (or a recent iPhone). Intel Macs and older devices can't run the on-device model. Orbit falls back to NaturalLanguage entity extraction.",
                isAvailable: false
            )
        case .appleIntelligenceNotEnabled:
            return SystemModelStatus(
                summary: "Not enabled",
                detail: "Turn on Apple Intelligence in System Settings → Apple Intelligence & Siri. In the simulator, enable it on the host Mac first — the simulator shares the Mac's downloaded model.",
                isAvailable: false
            )
        case .modelNotReady:
            return SystemModelStatus(
                summary: "Model downloading",
                detail: "Apple Intelligence is enabled but the on-device model isn't fully downloaded. Watch the progress in System Settings → Apple Intelligence & Siri.",
                isAvailable: false
            )
        @unknown default:
            return SystemModelStatus(
                summary: "Unavailable",
                detail: "Foundation Models reported a new unavailability reason this build doesn't know about yet.",
                isAvailable: false
            )
        }
    }
}
