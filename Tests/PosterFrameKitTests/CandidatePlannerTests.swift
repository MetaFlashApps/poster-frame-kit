import CoreMedia
import XCTest
@testable import PosterFrameKit

final class CandidatePlannerTests: XCTestCase {
    func testPlannerDistributesCandidatesAcrossInclusiveRange() throws {
        let options = try PosterFrameOptions(
            searchRange: 0.1...0.9,
            maximumFramesExamined: 5
        ).normalized()

        let times = try CandidatePlanner.timestamps(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            options: options
        )

        XCTAssertEqual(times.map(\.seconds), [1, 3, 5, 7, 9])
    }

    func testSingleCandidateUsesRangeMidpoint() throws {
        let options = try PosterFrameOptions(
            searchRange: 0.2...0.8,
            maximumFramesExamined: 1
        ).normalized()

        let times = try CandidatePlanner.timestamps(
            duration: CMTime(seconds: 20, preferredTimescale: 600),
            options: options
        )

        XCTAssertEqual(times.map(\.seconds), [10])
    }

    func testExcludedMidrollCandidatesAreOmitted() throws {
        let options = try PosterFrameOptions(
            searchRange: 0.1...0.9,
            maximumFramesExamined: 5,
            excludedRanges: [0.45...0.55]
        ).normalized()

        let times = try CandidatePlanner.timestamps(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            options: options
        )

        XCTAssertEqual(times.map(\.seconds), [1, 3, 7, 9])
    }

    func testSingleExcludedMidpointUsesWidestEarlierSegment() throws {
        let options = try PosterFrameOptions(
            searchRange: 0.1...0.9,
            maximumFramesExamined: 1,
            excludedRanges: [0.45...0.55]
        ).normalized()

        let times = try CandidatePlanner.timestamps(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            options: options
        )

        XCTAssertEqual(times.map(\.seconds), [2.75])
    }

    func testCollapsedRangeRequestsOneCandidate() throws {
        let options = try PosterFrameOptions(
            searchRange: 0.25...0.25,
            maximumFramesExamined: 40
        ).normalized()

        let times = try CandidatePlanner.timestamps(
            duration: CMTime(seconds: 8, preferredTimescale: 600),
            options: options
        )

        XCTAssertEqual(times.map(\.seconds), [2])
    }

    func testInvalidDurationIsRejected() throws {
        let options = try PosterFrameOptions().normalized()

        XCTAssertThrowsError(
            try CandidatePlanner.timestamps(duration: .zero, options: options)
        ) { error in
            XCTAssertEqual(error as? PosterFrameError, .invalidDuration)
        }
    }
}
