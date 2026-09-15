import CoreMedia
@testable import PosterFrameDemo
import XCTest

final class DemoVideoPositionTests: XCTestCase {
    func testPositionContainsTimestampAndNormalizedFraction() throws {
        let position = try XCTUnwrap(
            DemoVideoPosition(
                time: CMTime(seconds: 30, preferredTimescale: 600),
                duration: CMTime(seconds: 120, preferredTimescale: 600)
            )
        )

        XCTAssertEqual(position.timestampSeconds, 30)
        XCTAssertEqual(position.fraction, 0.25)
    }

    func testPositionClampsDecodedTimestampToVideoBounds() throws {
        let position = try XCTUnwrap(
            DemoVideoPosition(
                time: CMTime(seconds: 121, preferredTimescale: 600),
                duration: CMTime(seconds: 120, preferredTimescale: 600)
            )
        )

        XCTAssertEqual(position.fraction, 1)
    }

    func testPositionRejectsInvalidDuration() {
        XCTAssertNil(
            DemoVideoPosition(
                time: CMTime(seconds: 30, preferredTimescale: 600),
                duration: .zero
            )
        )
    }

    func testTimestampUsesStableHoursMinutesSecondsAndMilliseconds() throws {
        let timestamp = try XCTUnwrap(
            DemoTimestampFormatter.string(
                from: CMTime(seconds: 934.225, preferredTimescale: 1_000)
            )
        )

        XCTAssertEqual(timestamp, "00:15:34.225")
    }

    func testTimestampPreservesHours() throws {
        let timestamp = try XCTUnwrap(
            DemoTimestampFormatter.string(
                from: CMTime(seconds: 3_661.5, preferredTimescale: 1_000)
            )
        )

        XCTAssertEqual(timestamp, "01:01:01.500")
    }
}
