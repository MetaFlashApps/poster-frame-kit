import CoreGraphics
import CoreMedia
import XCTest

@testable import PosterFrameKit

final class AestheticSelectionTests: XCTestCase {
  func testAestheticPreferenceSelectsCloseMoreAestheticCandidate() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let aestheticAnalyzer = StubAestheticAnalyzer(
      results: [
        .success(AestheticAnalysis(score: -1, isUtilityFrame: true)),
        .success(AestheticAnalysis(score: 1, isUtilityFrame: false)),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        aestheticPreference: PosterFrameAestheticOptions(
          candidateCount: 2
        )
      ),
      aestheticAnalyzer: aestheticAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 2)
    XCTAssertEqual(result.aestheticScore, 1)
    XCTAssertEqual(
      result.aestheticAdjustment,
      1 - result.score,
      accuracy: 1e-12
    )
    XCTAssertEqual(result.adjustedScore, 1, accuracy: 1e-12)
    XCTAssertEqual(result.isUtilityFrame, false)
    XCTAssertEqual(aestheticAnalyzer.callCount, 2)
  }

  func testAestheticFailureDiscardsOnlyAestheticAdjustments() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let faceAnalyzer = StubFaceAnalyzer(
      results: [
        .success(
          FaceAnalysis(
            faceBounds: [
              CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
            ]
          )
        ),
        .success(.none),
      ]
    )
    let aestheticAnalyzer = StubAestheticAnalyzer(
      results: [
        .success(AestheticAnalysis(score: -1, isUtilityFrame: true)),
        .failure(.unsupportedVideo),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        facePreference: PosterFrameFaceOptions(candidateCount: 2),
        aestheticPreference: PosterFrameAestheticOptions(
          candidateCount: 2
        )
      ),
      faceAnalyzer: faceAnalyzer,
      aestheticAnalyzer: aestheticAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertNil(result.aestheticScore)
    XCTAssertNil(result.isUtilityFrame)
    XCTAssertEqual(result.aestheticAdjustment, 0)
    XCTAssertEqual(result.faceCompositionBonus, 0.04, accuracy: 1e-12)
    XCTAssertEqual(faceAnalyzer.callCount, 2)
    XCTAssertEqual(aestheticAnalyzer.callCount, 2)
  }

  func testZeroAestheticAdjustmentSkipsAnalysis() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let aestheticAnalyzer = StubAestheticAnalyzer(
      results: [.failure(.unsupportedVideo)]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        aestheticPreference: PosterFrameAestheticOptions(
          maximumAdjustment: 0
        )
      ),
      aestheticAnalyzer: aestheticAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertNil(result.aestheticScore)
    XCTAssertEqual(aestheticAnalyzer.callCount, 0)
  }

  func testAestheticCancellationIsPropagated() async throws {
    let source = try tiedCandidateSource(actualTimes: [1])
    let aestheticAnalyzer = StubAestheticAnalyzer(
      results: [.failure(.cancelled)]
    )

    do {
      _ = try await PosterFrameKit.selectBestFrame(
        from: source,
        options: PosterFrameOptions(
          maximumFramesExamined: 1,
          aestheticPreference: PosterFrameAestheticOptions(
            candidateCount: 1
          )
        ),
        aestheticAnalyzer: aestheticAnalyzer
      )
      XCTFail("Expected cancellation")
    } catch PosterFrameError.cancelled {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUnavailableAestheticAnalyzerLeavesRankingUnchanged() async throws {
    let source = try tiedCandidateSource(actualTimes: [2, 1])

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        aestheticPreference: PosterFrameAestheticOptions()
      ),
      aestheticAnalyzer: nil
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertNil(result.aestheticScore)
    XCTAssertEqual(result.aestheticAdjustment, 0)
  }

}
