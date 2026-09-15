import CoreGraphics
import CoreMedia
import XCTest

@testable import PosterFrameKit

final class SubtitleSelectionTests: XCTestCase {
  func testSubtitlePenaltySelectsCleanCloseCandidate() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let subtitleAnalyzer = StubSubtitleAnalyzer(
      results: [
        .success(
          SubtitleAnalysis(
            likelihood: 1,
            usedAccurateRecognition: false
          )
        ),
        .success(.none),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        subtitleAvoidance: PosterFrameSubtitleOptions(
          candidateCount: 2,
          maximumPenalty: 0.08
        )
      ),
      subtitleAnalyzer: subtitleAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 2)
    XCTAssertEqual(result.subtitlePenalty, 0)
    XCTAssertEqual(result.adjustedScore, result.score)
    XCTAssertEqual(subtitleAnalyzer.callCount, 2)
  }

  func testDefaultSubtitleBudgetReachesCleanSixthCandidate() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2, 3, 4, 5, 6])
    let subtitle = SubtitleAnalysis(
      likelihood: 1,
      usedAccurateRecognition: false
    )
    let subtitleAnalyzer = StubSubtitleAnalyzer(
      results: [
        .success(subtitle),
        .success(subtitle),
        .success(subtitle),
        .success(subtitle),
        .success(subtitle),
        .success(.none),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 6,
        subtitleAvoidance: PosterFrameSubtitleOptions()
      ),
      subtitleAnalyzer: subtitleAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 6)
    XCTAssertEqual(result.subtitlePenalty, 0)
    XCTAssertEqual(subtitleAnalyzer.callCount, 6)
  }

  func testCleanWinnerStopsSubtitleAnalysisEarly() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2, 3, 4, 5])
    let subtitleAnalyzer = StubSubtitleAnalyzer(results: [.success(.none)])

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 5,
        subtitleAvoidance: PosterFrameSubtitleOptions()
      ),
      subtitleAnalyzer: subtitleAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(subtitleAnalyzer.callCount, 1)
  }

  func testSubtitleFailureDiscardsCompleteReranking() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let subtitleAnalyzer = StubSubtitleAnalyzer(
      results: [
        .success(
          SubtitleAnalysis(
            likelihood: 1,
            usedAccurateRecognition: false
          )
        ),
        .failure(.unsupportedVideo),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 2)
      ),
      subtitleAnalyzer: subtitleAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(result.subtitlePenalty, 0)
    XCTAssertEqual(subtitleAnalyzer.callCount, 2)
  }

  func testSubtitleCancellationIsPropagated() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let subtitleAnalyzer = StubSubtitleAnalyzer(
      results: [
        .success(
          SubtitleAnalysis(
            likelihood: 1,
            usedAccurateRecognition: false
          )
        ),
        .failure(.cancelled),
      ]
    )

    do {
      _ = try await PosterFrameKit.selectBestFrame(
        from: source,
        options: PosterFrameOptions(
          maximumFramesExamined: 2,
          subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 2)
        ),
        subtitleAnalyzer: subtitleAnalyzer
      )
      XCTFail("Expected cancellation")
    } catch PosterFrameError.cancelled {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testZeroSubtitlePenaltySkipsRecognition() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let subtitleAnalyzer = StubSubtitleAnalyzer(results: [])

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        subtitleAvoidance: PosterFrameSubtitleOptions(
          candidateCount: 2,
          maximumPenalty: 0
        )
      ),
      subtitleAnalyzer: subtitleAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(subtitleAnalyzer.callCount, 0)
  }

}
