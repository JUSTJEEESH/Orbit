import WidgetKit
import SwiftUI
import OrbitDesignSystem

struct QuickCaptureWidget: Widget {
    let kind: String = "com.orbit.app.widgets.quickcapture"

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
        VStack(alignment: .leading, spacing: OrbitSpacing.sm) {
            Spacer()
            ZStack {
                Circle()
                    .fill(OrbitColor.textPrimary)
                    .frame(width: 48, height: 48)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(OrbitColor.textInverted)
            }
            Text("Capture")
                .font(OrbitTypography.title3)
                .foregroundStyle(OrbitColor.textPrimary)
            Text("Tap to save a thought.")
                .font(OrbitTypography.footnote)
                .foregroundStyle(OrbitColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "orbit://capture"))
    }
}
