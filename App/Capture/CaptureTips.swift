import SwiftUI
import TipKit

/// Teaches hold-to-talk once, at the moment it's useful, then never again.
struct HoldToTalkTip: Tip {
    var title: Text { Text("Hold to talk") }
    var message: Text? { Text("Touch and hold the mic, say what's on your mind, and let go. It's saved — no typing.") }
    var image: Image? { Image(systemName: "mic.fill") }

    var options: [any TipOption] {
        [Tips.MaxDisplayCount(1)]
    }
}
