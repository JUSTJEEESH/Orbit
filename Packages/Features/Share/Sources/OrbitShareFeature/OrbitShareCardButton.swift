import SwiftUI
import OrbitDesignSystem

/// Toolbar-friendly button that lazily renders a share card on view
/// appearance, then hands a real `ShareLink` to the user.
///
/// Two-state UI keeps the toolbar slot stable: a tiny spinner while the
/// `ImageRenderer` is doing its 1080×1350 pass, then the standard
/// `square.and.arrow.up` glyph once the PNG is ready. On a modern device
/// the render completes well inside a single frame, so the spinner is
/// rarely visible — but it prevents the share button from "popping in"
/// after first launch.
public struct OrbitShareCardButton<Card: View>: View {
    private let card: () -> Card
    private let previewTitle: String

    @State private var item: ShareCardItem?

    public init(
        previewTitle: String = "Share to…",
        @ViewBuilder card: @escaping () -> Card
    ) {
        self.previewTitle = previewTitle
        self.card = card
    }

    public var body: some View {
        Group {
            if let item {
                ShareLink(
                    item: item,
                    preview: SharePreview(previewTitle, image: Image(uiImage: item.image))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OrbitColor.textPrimary)
                }
                .accessibilityLabel("Share")
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(OrbitColor.textPrimary)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
        }
        .task {
            // Yield once so the host view's first paint completes before
            // we monopolize main for the render pass.
            await Task.yield()
            item = ShareCardItem { card() }
        }
    }
}
