import WidgetKit
import SwiftUI
import OrbitDesignSystem

struct QuickCaptureWidget: Widget {
    let kind: String = "com.joshgreen.orbit.widgets.quickcapture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetView(entry: entry)
                .containerBackground(OrbitColor.background, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("Open Orbit straight to capture.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        // Static widget — no need to refresh on a schedule, only when the
        // app tells WidgetCenter to reload after data changes.
        let entry = QuickCaptureEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickCaptureWidgetView: View {
    let entry: QuickCaptureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            // The label + glyph are a single visual unit, centered in
            // the remaining vertical space. Two Spacers around the
            // stack do the centering — flexible above and below so the
            // composition rebalances on systemMedium without code.
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(OrbitColor.textPrimary)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(OrbitColor.textInverted)
                }
                Text("Capture")
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "orbit://capture"))
    }

    /// Matches the editorial eyebrow on the other two widgets so the
    /// three feel like one family. Accent dot is theme-tinted.
    private var eyebrow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(OrbitColor.accent)
                .frame(width: 6, height: 6)
            Text("QUICK CAPTURE")
                .font(OrbitTypography.caption)
                .tracking(0.9)
                .foregroundStyle(OrbitColor.textTertiary)
        }
    }
}
