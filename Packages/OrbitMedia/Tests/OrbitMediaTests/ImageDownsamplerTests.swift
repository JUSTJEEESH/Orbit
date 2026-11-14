import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import OrbitMedia

@Suite("Image downsampling")
struct ImageDownsamplerTests {

    /// A solid-colour PNG of the given size, built without UIKit.
    private func makePNG(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            output as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func pixelSize(of jpeg: Data) throws -> (width: Int, height: Int) {
        let source = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    @Test func capsLongEdgeAndKeepsAspectRatio() throws {
        let jpeg = try #require(ImageDownsampler.jpegData(from: try makePNG(width: 6_000, height: 3_000), maxPixelSize: 1_000))
        let size = try pixelSize(of: jpeg)
        #expect(size.width == 1_000)
        #expect(size.height == 500)
    }

    @Test func leavesSmallImagesAtTheirSize() throws {
        let jpeg = try #require(ImageDownsampler.jpegData(from: try makePNG(width: 400, height: 300)))
        let size = try pixelSize(of: jpeg)
        #expect(size.width == 400)
        #expect(size.height == 300)
    }

    @Test func rejectsNonImageData() {
        #expect(ImageDownsampler.jpegData(from: Data("not an image".utf8)) == nil)
    }
}
