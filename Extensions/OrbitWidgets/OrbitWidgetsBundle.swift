import WidgetKit
import SwiftUI

@main
struct OrbitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickCaptureWidget()
        RecentMemoryWidget()
    }
}
