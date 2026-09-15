@testable import PosterFrameDemo
import XCTest

final class DemoPerformanceComparisonTests: XCTestCase {
    func testPosterFrameKitWinCombinesCaptureAndVisionRanking() throws {
        let comparison = try XCTUnwrap(
            DemoPerformanceComparison(
                posterFrameDuration: .milliseconds(250),
                candidateCaptureDuration: .milliseconds(600),
                visionRankingDuration: .milliseconds(150)
            )
        )

        XCTAssertEqual(comparison.visionPipelineDuration, .milliseconds(750))
        XCTAssertEqual(comparison.winner, .posterFrameKit)
        XCTAssertEqual(comparison.speedupFactor, 3, accuracy: 0.000_001)
        XCTAssertEqual(
            comparison.timeSavedFraction,
            2.0 / 3.0,
            accuracy: 0.000_001
        )
    }

    func testVisionPipelineCanWin() throws {
        let comparison = try XCTUnwrap(
            DemoPerformanceComparison(
                posterFrameDuration: .seconds(1),
                candidateCaptureDuration: .milliseconds(250),
                visionRankingDuration: .milliseconds(150)
            )
        )

        XCTAssertEqual(comparison.winner, .visionPipeline)
        XCTAssertEqual(comparison.speedupFactor, 2.5, accuracy: 0.000_001)
        XCTAssertEqual(comparison.timeSavedFraction, 0.6, accuracy: 0.000_001)
    }

    func testDurationsWithinOnePercentAreTreatedAsTie() throws {
        let comparison = try XCTUnwrap(
            DemoPerformanceComparison(
                posterFrameDuration: .milliseconds(1_000),
                candidateCaptureDuration: .milliseconds(800),
                visionRankingDuration: .milliseconds(205)
            )
        )

        XCTAssertEqual(comparison.winner, .tie)
    }

    func testNonPositiveDurationsAreRejected() {
        XCTAssertNil(
            DemoPerformanceComparison(
                posterFrameDuration: .zero,
                candidateCaptureDuration: .milliseconds(200),
                visionRankingDuration: .milliseconds(100)
            )
        )
    }
}
