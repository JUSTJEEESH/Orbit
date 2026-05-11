import Foundation
import AuthenticationServices
import Observation

/// Owns the Sign in with Apple lifecycle. Stores the stable `user`
/// identifier in the Keychain (not full name / email — those are returned
/// only on the very first sign-in and should be persisted to the app's own
/// store, not Keychain).
///
/// Surfaces `AccountState` for the UI to observe. Re-checks the credential
/// state on launch so a revoked sign-in flips the state to `.revoked`
/// instead of pretending the user is still signed in.
@MainActor
@Observable
public final class AccountService {
    public private(set) var state: AccountState = .guest

    private let keychain: KeychainStore
    private static let userIDKey = "siwa.user"
    private static let fullNameKey = "siwa.fullName"
    private static let emailKey = "siwa.email"

    public init() {
        self.keychain = KeychainStore(service: "com.orbit.app.account")
        self.state = Self.restore(from: keychain)
    }

    // MARK: - Public

    /// Call this from the SwiftUI `SignInWithAppleButton`'s `onCompletion`.
    public func handle(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case .success(let authorization):
            handle(authorization)
        case .failure(let error):
            // ASAuthorizationError.canceled is benign; surface only real
            // failures via the state if needed in a future iteration.
            _ = error
        }
    }

    /// Refreshes the SIWA credential state. If Apple reports the credential
    /// is no longer authorized, drop to `.revoked` so the UI prompts a
    /// re-sign-in.
    public func refreshCredentialState() async {
        guard case .signedIn(let identity) = state else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let credentialState = try await provider.credentialState(forUserID: identity.userIdentifier)
            switch credentialState {
            case .authorized:
                break
            case .revoked, .notFound, .transferred:
                state = .revoked
            @unknown default:
                state = .revoked
            }
        } catch {
            // Network issues etc. — keep current state; we'll retry next launch.
        }
    }

    public func signOut() {
        keychain.remove(forKey: Self.userIDKey)
        keychain.remove(forKey: Self.fullNameKey)
        keychain.remove(forKey: Self.emailKey)
        state = .guest
    }

    // MARK: - Internals

    private func handle(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        let userID = credential.user

        // Apple returns full name and email only on the first authorization.
        // Persist them the moment we see them; subsequent sign-ins will
        // reuse what's already on disk.
        if let nameComponents = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let name = formatter.string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                keychain.setString(name, forKey: Self.fullNameKey)
            }
        }
        if let email = credential.email, !email.isEmpty {
            keychain.setString(email, forKey: Self.emailKey)
        }
        keychain.setString(userID, forKey: Self.userIDKey)

        state = .signedIn(SignedInIdentity(
            userIdentifier: userID,
            fullName: keychain.string(forKey: Self.fullNameKey),
            email: keychain.string(forKey: Self.emailKey)
        ))
    }

    private static func restore(from keychain: KeychainStore) -> AccountState {
        guard let userID = keychain.string(forKey: userIDKey), !userID.isEmpty else {
            return .guest
        }
        return .signedIn(SignedInIdentity(
            userIdentifier: userID,
            fullName: keychain.string(forKey: fullNameKey),
            email: keychain.string(forKey: emailKey)
        ))
    }
}
