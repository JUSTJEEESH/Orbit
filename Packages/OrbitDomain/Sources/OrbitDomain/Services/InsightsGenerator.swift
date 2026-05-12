import Foundation

/// Computes `SmartInsight` observations from a list of memories. The engine
/// implementation lives in OrbitAI (NLTagger, NSDataDetector, etc.); this
/// protocol keeps the domain layer pure.
public protocol InsightsGenerator: Sendable {
    func generate(from memories: [Memory], now: Date) async -> [SmartInsight]
}
