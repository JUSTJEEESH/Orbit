import Foundation

/// Account state surfaced to the app. The `revoked` case captures the
/// scenario where Apple returns a non-authorized credential state on
/// relaunch (user revoked in Settings, signed in elsewhere, etc.) — the
/// app should treat that as "needs to sign in again" rather than crashing
/// or silently dropping data.
public enum AccountState: Sendable, Equatable {
    case guest
    case signedIn(SignedInIdentity)
    case revoked

    public var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    public var displayName: String? {
        if case .signedIn(let identity) = self { return identity.fullName }
        return nil
    }

    public var emailHint: String? {
        if case .signedIn(let identity) = self { return identity.email }
        return nil
    }
}

public struct SignedInIdentity: Sendable, Equatable {
    public let userIdentifier: String
    public let fullName: String?
    public let email: String?

    public init(userIdentifier: String, fullName: String?, email: String?) {
        self.userIdentifier = userIdentifier
        self.fullName = fullName
        self.email = email
    }
}
