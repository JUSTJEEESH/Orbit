import Foundation

/// Typed error space shared across domain boundaries. Feature surfaces map
/// these into user-facing strings via the design system.
public enum OrbitError: Error, Sendable, Equatable {
    case notFound
    case persistenceFailed(String)
    case syncUnavailable
    case aiUnavailable
    case rateLimited
    case unauthorized
    case offline
    case unknown(String)
}
