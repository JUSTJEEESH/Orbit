import Foundation

/// Friendly `Sendable` snapshot of a StoreKit `Product`. We don't expose
/// StoreKit types past this boundary so features can compile and preview
/// without dragging StoreKit in.
public struct OrbitProduct: Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let kind: Kind

    public enum Kind: Sendable, Hashable {
        case monthly
        case yearly
        case lifetime
        case unknown
    }

    public init(id: String, displayName: String, description: String, displayPrice: String, kind: Kind) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.kind = kind
    }
}
