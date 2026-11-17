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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock Screen: one tap to start talking.
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title3)
            }
            .widgetURL(OrbitCaptureLinks.record)
            .accessibilityLabel("Record a memory")
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                Text("Record a memory")
                    .font(.headline)
                    .widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(OrbitCaptureLinks.record)
        case .systemMedium:
            mediumCapture
        default:
            homeScreenCapture
        }
    }

    /// Medium: two buttons — write or talk — each a deep link.
    private var mediumCapture: some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                captureButton(title: "Write", systemImage: "square.and.pencil", url: OrbitCaptureLinks.write)
                captureButton(title: "Talk", systemImage: "mic.fill", url: OrbitCaptureLinks.record)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func captureButton(title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(OrbitColor.textInverted)
                    .frame(width: 44, height: 44)
                    .background(OrbitColor.textPrimary, in: .circle)
                Text(title)
                    .font(OrbitTypography.bodyEmphasized)
                    .foregroundStyle(OrbitColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(title == "Talk" ? "Record a memory" : "Write a memory")
    }

    private var homeScreenCapture: some View {
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
