import CoreGraphics
import CoreMedia
import XCTest

@testable import PosterFrameKit

final class FaceSelectionTests: XCTestCase {
  func testFacePreferenceSelectsCloseCandidateWithStrongComposition() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let faceAnalyzer = StubFaceAnalyzer(
      results: [
        .success(.none),
        .success(
          FaceAnalysis(
            faceBounds: [
              CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
            ]
          )
        ),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        facePreference: PosterFrameFaceOptions(candidateCount: 2)
      ),
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 2)
    XCTAssertEqual(result.faceCompositionBonus, 0.04, accuracy: 1e-12)
    XCTAssertEqual(
      result.adjustedScore,
      min(result.score + 0.04, 1),
      accuracy: 1e-12
    )
    XCTAssertEqual(faceAnalyzer.callCount, 2)
  }

  func testLowConfidenceFaceDoesNotChangeSelection() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let faceAnalyzer = StubFaceAnalyzer(
      results: [
        .success(.none),
        .success(
          FaceAnalysis(
            faceBounds: [
              CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
            ],
            faceConfidences: [0.69]
          )
        ),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        facePreference: PosterFrameFaceOptions(candidateCount: 2)
      ),
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(result.faceCompositionBonus, 0)
    XCTAssertEqual(faceAnalyzer.callCount, 2)
  }

  func testFaceAnalysisFailureDiscardsFaceBonuses() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let faceAnalyzer = StubFaceAnalyzer(
      results: [
        .success(.none),
        .failure(.unsupportedVideo),
      ]
    )

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        facePreference: PosterFrameFaceOptions(candidateCount: 2)
      ),
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(result.faceCompositionBonus, 0)
    XCTAssertEqual(faceAnalyzer.callCount, 2)
  }

  func testFaceCancellationIsPropagated() async throws {
    let source = try tiedCandidateSource(actualTimes: [1])
    let faceAnalyzer = StubFaceAnalyzer(results: [.failure(.cancelled)])

    do {
      _ = try await PosterFrameKit.selectBestFrame(
        from: source,
        options: PosterFrameOptions(
          maximumFramesExamined: 1,
          facePreference: PosterFrameFaceOptions(candidateCount: 1)
        ),
        faceAnalyzer: faceAnalyzer
      )
      XCTFail("Expected cancellation")
    } catch PosterFrameError.cancelled {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testZeroFaceBonusSkipsDetection() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2])
    let faceAnalyzer = StubFaceAnalyzer(results: [.failure(.unsupportedVideo)])

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 2,
        facePreference: PosterFrameFaceOptions(maximumBonus: 0)
      ),
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(faceAnalyzer.callCount, 0)
  }

  func testFaceAndSubtitleAdjustmentsCompose() async throws {
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
        subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 2),
        facePreference: PosterFrameFaceOptions(candidateCount: 2)
      ),
      subtitleAnalyzer: subtitleAnalyzer,
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 2)
    XCTAssertEqual(result.faceCompositionBonus, 0)
    XCTAssertEqual(result.subtitlePenalty, 0)
    XCTAssertEqual(faceAnalyzer.callCount, 2)
    XCTAssertEqual(subtitleAnalyzer.callCount, 2)
  }

  func testCombinedRefinementsRetainLargestConfiguredLeadingGroup() async throws {
    let source = try tiedCandidateSource(actualTimes: [1, 2, 3, 4])
    let faceAnalyzer = StubFaceAnalyzer(
      results: [
        .success(.none),
        .success(.none),
        .success(.none),
        .success(
          FaceAnalysis(
            faceBounds: [
              CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
            ]
          )
        ),
      ]
    )
    let subtitleAnalyzer = StubSubtitleAnalyzer(results: [.success(.none)])

    let result = try await PosterFrameKit.selectBestFrame(
      from: source,
      options: PosterFrameOptions(
        maximumFramesExamined: 4,
        subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 2),
        facePreference: PosterFrameFaceOptions(candidateCount: 4)
      ),
      subtitleAnalyzer: subtitleAnalyzer,
      faceAnalyzer: faceAnalyzer
    )

    XCTAssertEqual(result.time.seconds, 4)
    XCTAssertEqual(result.faceCompositionBonus, 0.04, accuracy: 1e-12)
    XCTAssertEqual(faceAnalyzer.callCount, 4)
    XCTAssertEqual(subtitleAnalyzer.callCount, 1)
  }

}
