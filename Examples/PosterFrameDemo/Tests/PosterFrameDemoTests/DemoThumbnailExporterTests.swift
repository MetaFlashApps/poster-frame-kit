import CoreGraphics
import ImageIO
@testable import PosterFrameDemo
import XCTest

final class DemoThumbnailExporterTests: XCTestCase {
    func testSuggestedFilenameIsSafeAndDescriptive() {
        XCTAssertEqual(
            DemoThumbnailExporter.suggestedFilename(for: "Hybrid 50/50"),
            "hybrid-50-50-thumbnail.png"
        )
        XCTAssertEqual(
            DemoThumbnailExporter.suggestedFilename(for: "///"),
            "thumbnail.png"
        )
    }

    func testWritePNGProducesReadableImage() throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "DemoThumbnailExporterTests-\(UUID().uuidString).png"
        )
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: 2,
                height: 2,
                bitsPerComponent: 8,
                bytesPerRow: 8,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = try XCTUnwrap(context.makeImage())

        try DemoThumbnailExporter.writePNG(image, to: url)

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(decoded.width, 2)
        XCTAssertEqual(decoded.height, 2)
    }
}
