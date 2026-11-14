import Foundation
import LocalAuthentication
import Observation

/// Optional Face ID / Touch ID / passcode lock for the whole app.
///
/// When enabled, Orbit locks whenever it leaves the foreground and asks for
/// device authentication on return. `deviceOwnerAuthentication` (not the
/// biometrics-only policy) is used deliberately: if Face ID fails or isn't
/// enrolled, the device passcode still opens the app, so nobody can be
/// locked out of their own memories.
@MainActor
@Observable
public final class AppLockService {
    public private(set) var isEnabled: Bool
    public private(set) var isLocked: Bool
    public private(set) var isAuthenticating = false

    private let defaults: UserDefaults
    private static let enabledKey = "orbit.privacy.appLockEnabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.enabledKey)
        self.isEnabled = enabled
        // Cold launch starts locked, so content never flashes before Face ID.
        self.isLocked = enabled
    }

    /// "Face ID", "Touch ID", "Optic ID" or "Passcode" — for labels.
    public var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Passcode"
        }
    }

    /// Whether the device has any passcode / biometric set up at all.
    public var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Turns the lock on or off. Both directions require authenticating, so
    /// someone holding an unlocked phone can't silently disable it.
    /// - Returns: whether the change was applied.
    @discardableResult
    public func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled != isEnabled else { return true }
        let reason = enabled ? "Lock Orbit with \(methodName)" : "Turn off the Orbit lock"
        guard await authenticate(reason: reason) else { return false }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        return true
    }

    /// Called when the app leaves the foreground.
    public func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    /// Prompts for Face ID / passcode and unlocks on success.
    public func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate(reason: "Unlock your memories") {
            isLocked = false
        }
    }

    private func authenticate(reason: String) async -> Bool {
        isAuthenticating = true
        defer { isAuthenticating = false }
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            OrbitLog.app.info("App lock authentication not completed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
