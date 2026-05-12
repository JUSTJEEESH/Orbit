import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// A renderable share card paired with its serialized PNG bytes.
///
/// Used as the `Transferable` payload for SwiftUI `ShareLink`. Rendering
/// is eager and `@MainActor`-bound because `ImageRenderer` is — we let
/// the caller decide when to do that work (typically `.task` on view
/// appear, not on every body eval).
public struct ShareCardItem: Transferable, @unchecked Sendable {
    public let data: Data
    public let image: UIImage

    @MainActor
    public init?<Content: View>(@ViewBuilder view: () -> Content) {
        let size = CGSize(width: 1080, height: 1350)
        let renderer = ImageRenderer(
            content: view()
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .light)
        )
        // Disable display-scale upscaling — we already chose pixel
        // dimensions explicitly, doubling them would just bloat exports
        // without changing visible quality.
        renderer.scale = 1
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData()
        else { return nil }
        self.data = data
        self.image = uiImage
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}
