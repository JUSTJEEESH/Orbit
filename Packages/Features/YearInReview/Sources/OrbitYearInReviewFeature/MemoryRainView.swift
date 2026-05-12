import SwiftUI
import OrbitDesignSystem
import OrbitDomain

/// Closing visual for Year in Review. Small theme-tinted memory chips drift
/// down like leaves in the wind, each gently swaying as it falls. Tap any
/// to dismiss; the rain repopulates so the screen never empties.
///
/// `TimelineView(.animation)` drives the per-frame positions so we don't
/// need a long-running animation engine. State is deliberately tiny — each
/// "particle" carries its own seed for size, drift, and lateral sway so
/// the motion never looks gridded.
struct MemoryRainView: View {
    let memories: [Memory]
    let onTapMemory: @MainActor (Memory) -> Void

    @State private var particles: [Particle]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitTheme) private var orbitTheme

    init(memories: [Memory], onTapMemory: @escaping @MainActor (Memory) -> Void) {
        self.memories = memories
        self.onTapMemory = onTapMemory
        _particles = State(initialValue: Self.makeParticles(memories: memories, count: 22))
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(particles) { particle in
                        chip(for: particle)
                            .position(position(of: particle, in: size, at: elapsed))
                            .opacity(opacity(of: particle, in: size, at: elapsed))
                            .onTapGesture {
                                if let memory = memory(for: particle) {
                                    onTapMemory(memory)
                                }
                            }
                    }
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .allowsHitTesting(!reduceMotion)
        .accessibilityHidden(true)
    }

    private func chip(for particle: Particle) -> some View {
        let memory = memory(for: particle)
        let tint = OrbitCategoryPalette.tint(for: memory?.ai.category)
        return Text(particle.text)
            .font(.system(size: particle.fontSize, weight: .medium, design: .serif))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10), in: .capsule)
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.25), lineWidth: 0.5)
            )
    }

    private func memory(for particle: Particle) -> Memory? {
        particle.memoryID.flatMap { id in memories.first { $0.id == id } }
    }

    private func position(of particle: Particle, in size: CGSize, at elapsed: TimeInterval) -> CGPoint {
        // Reduce Motion: park each chip in its lateral lane without falling.
        guard !reduceMotion else {
            return CGPoint(
                x: lateralPosition(of: particle, in: size, at: 0),
                y: size.height * particle.parkedYFraction
            )
        }

        // Loop the vertical fall so the rain never ends. Each particle's
        // own phase makes the loop invisible — different chips reach the
        // bottom at different times.
        let loopDuration = particle.duration
        let progress = ((elapsed + particle.phase) .truncatingRemainder(dividingBy: loopDuration)) / loopDuration
        let y = -60 + (size.height + 120) * CGFloat(progress)
        let x = lateralPosition(of: particle, in: size, at: elapsed)
        return CGPoint(x: x, y: y)
    }

    /// Gentle sway: a sine wave around the chip's home column. Different
    /// speed + amplitude per particle so they never look in lock-step.
    private func lateralPosition(of particle: Particle, in size: CGSize, at elapsed: TimeInterval) -> CGFloat {
        let baseX = size.width * particle.xFraction
        let sway = sin(elapsed * particle.swaySpeed + particle.swayPhase) * particle.swayAmplitude
        return baseX + CGFloat(sway)
    }

    private func opacity(of particle: Particle, in size: CGSize, at elapsed: TimeInterval) -> Double {
        guard !reduceMotion else { return 0.85 }
        // Fade in at top, hold middle, fade out near bottom — gives the
        // rain a soft horizon at each edge of the screen.
        let position = position(of: particle, in: size, at: elapsed).y
        let normalized = position / size.height
        if normalized < 0.05 { return Double(normalized / 0.05) * 0.85 }
        if normalized > 0.85 { return max(0, Double((1.0 - normalized) / 0.15)) * 0.85 }
        return 0.85
    }

    // MARK: - Particle model

    private struct Particle: Identifiable, Hashable {
        let id: UUID
        let memoryID: UUID?
        let text: String
        let fontSize: CGFloat
        let xFraction: CGFloat
        let phase: TimeInterval
        let duration: TimeInterval
        let swayPhase: Double
        let swaySpeed: Double
        let swayAmplitude: Double
        let parkedYFraction: CGFloat
    }

    private static func makeParticles(memories: [Memory], count: Int) -> [Particle] {
        guard !memories.isEmpty else { return [] }
        var rng = SystemRandomNumberGenerator()
        return (0..<count).map { index in
            let memory = memories[index % memories.count]
            return Particle(
                id: UUID(),
                memoryID: memory.id,
                text: shortLabel(for: memory),
                fontSize: CGFloat.random(in: 13...18, using: &rng),
                xFraction: CGFloat.random(in: 0.08...0.92, using: &rng),
                phase: TimeInterval.random(in: 0...12, using: &rng),
                duration: TimeInterval.random(in: 6.5...11, using: &rng),
                swayPhase: Double.random(in: 0...(2 * .pi), using: &rng),
                swaySpeed: Double.random(in: 0.6...1.4, using: &rng),
                swayAmplitude: Double.random(in: 8...22, using: &rng),
                parkedYFraction: CGFloat.random(in: 0.12...0.88, using: &rng)
            )
        }
    }

    private static func shortLabel(for memory: Memory) -> String {
        let raw: String = {
            if let summary = memory.ai.summary, !summary.isEmpty { return summary }
            switch memory.content {
            case .text(let s):                          return s
            case .voiceNote(let t, _):                  return t ?? "voice"
            case .image(let caption):                   return caption ?? "photo"
            case .link(_, let title, let summary):      return summary ?? title ?? "link"
            case .screenshot(let ocr):                  return ocr ?? "screenshot"
            case .location(let name, _, _):             return name ?? "place"
            }
        }()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = trimmed.split(separator: " ").prefix(3).joined(separator: " ")
        return truncated.isEmpty ? "memory" : truncated
    }
}

