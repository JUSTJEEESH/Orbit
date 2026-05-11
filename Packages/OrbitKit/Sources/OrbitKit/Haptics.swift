import UIKit

/// A small, curated haptic palette. Resist the urge to add new cases — premium
/// feel comes from using the same vocabulary everywhere, not from variety.
public enum OrbitHaptic: Sendable {
    case tap
    case selection
    case success
    case warning
    case failure
    case impactSoft
    case impactRigid
}

@MainActor
public enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    /// Prepare generators so the first call is not delayed by hardware spin-up.
    public static func prepare() {
        selection.prepare()
        notification.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        lightImpact.prepare()
    }

    public static func play(_ haptic: OrbitHaptic) {
        switch haptic {
        case .tap:           lightImpact.impactOccurred()
        case .selection:     selection.selectionChanged()
        case .success:       notification.notificationOccurred(.success)
        case .warning:       notification.notificationOccurred(.warning)
        case .failure:       notification.notificationOccurred(.error)
        case .impactSoft:    softImpact.impactOccurred()
        case .impactRigid:   rigidImpact.impactOccurred()
        }
    }
}
