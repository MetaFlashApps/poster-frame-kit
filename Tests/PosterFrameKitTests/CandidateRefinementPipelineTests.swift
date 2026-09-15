import XCTest

@testable import PosterFrameKit

final class CandidateRefinementPipelineTests: XCTestCase {
  func testLiveDependenciesDoNotCreateDisabledAnalyzers() throws {
    let options = try PosterFrameOptions(
      subtitleAvoidance: PosterFrameSubtitleOptions(maximumPenalty: 0),
      facePreference: PosterFrameFaceOptions(maximumBonus: 0),
      aestheticPreference: PosterFrameAestheticOptions(
        maximumAdjustment: 0
      )
    ).normalized()

    let dependencies = CandidateAnalysisDependencies.live(options: options)

    XCTAssertNil(dependencies.subtitleAnalyzer)
    XCTAssertNil(dependencies.faceAnalyzer)
    XCTAssertNil(dependencies.aestheticAnalyzer)
  }

  func testPipelineRetainsLargestActiveCandidateBudget() {
    let options = PosterFrameOptions(
      subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 5),
      facePreference: PosterFrameFaceOptions(candidateCount: 8),
      aestheticPreference: PosterFrameAestheticOptions(candidateCount: 24)
    )
    let pipeline = CandidateRefinementPipeline(
      options: options,
      dependencies: CandidateAnalysisDependencies(
        subtitleAnalyzer: StubSubtitleAnalyzer(results: []),
        faceAnalyzer: StubFaceAnalyzer(results: []),
        aestheticAnalyzer: StubAestheticAnalyzer(results: [])
      ),
      performanceRecorder: nil
    )

    XCTAssertTrue(pipeline.isActive)
    XCTAssertEqual(pipeline.retainedCandidateCount, 24)
  }

  func testUnavailableAnalyzersDisableRetentionAndRefinement() {
    let options = PosterFrameOptions(
      subtitleAvoidance: PosterFrameSubtitleOptions(),
      facePreference: PosterFrameFaceOptions(),
      aestheticPreference: PosterFrameAestheticOptions()
    )
    let pipeline = CandidateRefinementPipeline(
      options: options,
      dependencies: CandidateAnalysisDependencies(
        subtitleAnalyzer: nil,
        faceAnalyzer: nil,
        aestheticAnalyzer: nil
      ),
      performanceRecorder: nil
    )

    XCTAssertFalse(pipeline.isActive)
    XCTAssertEqual(pipeline.retainedCandidateCount, 0)
  }
}
