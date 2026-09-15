import CoreMedia
@testable import PosterFrameDemo
import XCTest

final class ComparisonRankerTests: XCTestCase {
    func testVisionAndHybridCanChooseDifferentCandidates() throws {
        let scores = [
            score(time: 1, vision: -0.8, posterFrame: 1),
            score(time: 2, vision: 0.9, posterFrame: 0),
        ]

        XCTAssertEqual(ComparisonRanker.bestVisionIndex(in: scores), 1)
        XCTAssertEqual(ComparisonRanker.bestHybridIndex(in: scores), 0)
        XCTAssertEqual(
            ComparisonRanker.hybridScore(for: scores[0]),
            0.55,
            accuracy: 1e-12
        )
    }

    func testEqualScoresPreferEarlierActualTime() {
        let scores = [
            score(time: 2, vision: 0.5, posterFrame: 0.5),
            score(time: 1, vision: 0.5, posterFrame: 0.5),
        ]

        XCTAssertEqual(ComparisonRanker.bestVisionIndex(in: scores), 1)
        XCTAssertEqual(ComparisonRanker.bestHybridIndex(in: scores), 1)
    }

    private func score(
        time: Double,
        vision: Double,
        posterFrame: Double
    ) -> VisionCandidateScore {
        VisionCandidateScore(
            time: CMTime(seconds: time, preferredTimescale: 600),
            visionScore: vision,
            posterFrameScore: posterFrame,
            isUtility: false
        )
    }
}
