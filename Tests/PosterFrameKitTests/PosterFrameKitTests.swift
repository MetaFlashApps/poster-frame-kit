import CoreGraphics
import XCTest
@testable import PosterFrameKit

final class PosterFrameKitTests: XCTestCase {
    func testDefaultOptionsDescribeBoundedGeneralSearch() {
        let options = PosterFrameOptions()

        XCTAssertEqual(options.searchRange, 0.08...0.90)
        XCTAssertEqual(options.maximumFramesExamined, 40)
        XCTAssertTrue(options.excludedRanges.isEmpty)
        XCTAssertEqual(options.profile, .general)
        XCTAssertNil(options.outputSize)
    }

    func testCustomProfilePreservesWeights() {
        let weights = PosterFrameWeights(
            sharpness: 0.4,
            contrast: 0.2,
            entropy: 0.2,
            colorfulness: 0.2
        )

        let options = PosterFrameOptions(
            profile: .custom(weights),
            outputSize: CGSize(width: 640, height: 360)
        )

        XCTAssertEqual(options.profile, .custom(weights))
        XCTAssertEqual(options.outputSize, CGSize(width: 640, height: 360))
    }
}
