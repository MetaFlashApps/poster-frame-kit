import AppKit
import XCTest
@testable import PosterFrameDemo

@MainActor
final class DemoApplicationDelegateTests: XCTestCase {
    func testBundledApplicationIconUsesTransparentMacOSPresentation() throws {
        let icon = try XCTUnwrap(DemoApplicationDelegate.applicationIcon)
        let representation = try XCTUnwrap(
            icon.representations.compactMap { $0 as? NSBitmapImageRep }.first
        )
        let cornerAlpha = try XCTUnwrap(
            representation.colorAt(x: 0, y: 0)?.alphaComponent
        )
        let centerAlpha = try XCTUnwrap(
            representation.colorAt(x: 512, y: 512)?.alphaComponent
        )

        XCTAssertEqual(representation.pixelsWide, 1_024)
        XCTAssertEqual(representation.pixelsHigh, 1_024)
        XCTAssertEqual(cornerAlpha, 0, accuracy: 0.01)
        XCTAssertEqual(centerAlpha, 1, accuracy: 0.01)
    }
}
