import SwiftUI

/// Live waveform view. Renders a scrolling bar graph of normalized RMS levels
/// using `Canvas` so 60+fps stays cheap even with hundreds of bars.
public struct VoiceWaveformView: View {
    private let levels: [Float]
    private let maxBars: Int
    private let color: Color

    public init(levels: [Float], maxBars: Int = 60, color: Color = OrbitColor.textPrimary) {
        self.levels = levels
        self.maxBars = maxBars
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let visible = Array(levels.suffix(maxBars))
                let slot = size.width / CGFloat(maxBars)
                let barWidth = max(2, slot * 0.5)
                let barSpacing = slot - barWidth
                let baseline = size.height / 2

                for (index, level) in visible.enumerated() {
                    let x = CGFloat(maxBars - visible.count + index) * (barWidth + barSpacing)
                    let amplitude = CGFloat(level)
                    let height = max(2, amplitude * (size.height - 4))
                    let rect = CGRect(
                        x: x,
                        y: baseline - height / 2,
                        width: barWidth,
                        height: height
                    )
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    context.fill(path, with: .color(color))
                }
            }
        }
        .frame(height: 64)
        .accessibilityHidden(true)
    }
}

#Preview {
    VoiceWaveformView(levels: (0..<60).map { _ in Float.random(in: 0.1...0.9) })
        .padding()
        .preferredColorScheme(.dark)
}
