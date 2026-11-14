import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Memory-safe image re-encoding built on ImageIO.
///
/// `UIImage(data:)` decodes the full bitmap: a 48 MP photo is ~190 MB in
/// memory, far past the Share Extension's limit, so 1.x could be killed
/// mid-save. ImageIO's thumbnailer decodes straight to the target size
/// instead, and applies the EXIF orientation while it does.
public enum ImageDownsampler {
    /// Long-edge cap for stored photos. Sharp on any iPhone screen and in
    /// share cards, while a decoded bitmap stays around 28 MB.
    public static let defaultMaxPixelSize = 3_072
    public static let defaultJPEGQuality = 0.85

    /// Re-encodes image bytes (HEIC, PNG, JPEG…) as an upright JPEG no larger
    /// than `maxPixelSize` on its long edge. Returns nil if the data isn't a
    /// readable image.
    public static func jpegData(
        from data: Data,
        maxPixelSize: Int = defaultMaxPixelSize,
        quality: Double = defaultJPEGQuality
    ) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        return encode(source, maxPixelSize: maxPixelSize, quality: quality)
    }

    /// Same as `jpegData(from:)`, reading from a file without loading the
    /// whole file into memory first.
    public static func jpegData(
        contentsOf url: URL,
        maxPixelSize: Int = defaultMaxPixelSize,
        quality: Double = defaultJPEGQuality
    ) -> Data? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        return encode(source, maxPixelSize: maxPixelSize, quality: quality)
    }

    private static func encode(_ source: CGImageSource, maxPixelSize: Int, quality: Double) -> Data? {
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        let properties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
