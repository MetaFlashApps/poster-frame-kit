import CoreGraphics
import CoreMedia
import XCTest

@testable import PosterFrameKit

final class FaceAnalysisTests: XCTestCase {
  func testVisionFaceAnalyzerDoesNotDetectFaceInFlatFrame() async throws {
    let pixelBuffer = try TestPixelBufferFactory.bgra(
      width: 64,
      height: 64
    ) { _, _ in
      (blue: 128, green: 128, red: 128)
    }

    let analysis = try await makeFaceAnalyzer().analyze(pixelBuffer)

    XCTAssertEqual(analysis, .none)
  }

  func testCompositionScorerIgnoresMissingTinyAndInvalidFaces() {
    XCTAssertEqual(FaceCompositionScorer.quality(for: []), 0)
    XCTAssertEqual(
      FaceCompositionScorer.quality(
        for: [CGRect(x: 0.49, y: 0.49, width: 0.05, height: 0.05)]
      ),
      0
    )
    XCTAssertEqual(
      FaceCompositionScorer.quality(
        for: [CGRect(x: .nan, y: 0, width: 0.2, height: 0.2)]
      ),
      0
    )
  }

  func testCompositionScorerRewardsVisibleCenteredFace() {
    let centered = FaceCompositionScorer.quality(
      for: [CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.40)]
    )
    let peripheral = FaceCompositionScorer.quality(
      for: [CGRect(x: 0, y: 0, width: 0.30, height: 0.40)]
    )

    XCTAssertGreaterThan(centered, peripheral)
    XCTAssertGreaterThan(centered, 0.9)
    XCTAssertLessThanOrEqual(centered, 1)
  }

  func testCompositionScorerAppliesBoundedGroupBonus() {
    let face = CGRect(x: 0.35, y: 0.35, width: 0.2, height: 0.25)
    let single = FaceCompositionScorer.quality(for: [face])
    let group = FaceCompositionScorer.quality(
      for: [
        face,
        CGRect(x: 0.58, y: 0.38, width: 0.18, height: 0.23),
      ]
    )

    XCTAssertGreaterThan(group, single)
    XCTAssertLessThanOrEqual(group, 1)
  }

  func testCompositionScorerWeightsReliableDetectionConfidence() {
    let face = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
    let certain = FaceCompositionScorer.quality(
      for: [face],
      confidences: [1]
    )
    let lowerConfidence = FaceCompositionScorer.quality(
      for: [face],
      confidences: [0.8]
    )

    XCTAssertEqual(lowerConfidence, certain * 0.8, accuracy: 1e-7)
  }

  func testCompositionScorerIgnoresUnreliableDetection() {
    let face = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)

    XCTAssertEqual(
      FaceCompositionScorer.quality(
        for: [face],
        confidences: [0.69]
      ),
      0
    )
    XCTAssertGreaterThan(
      FaceCompositionScorer.quality(
        for: [face],
        confidences: [0.70]
      ),
      0
    )
  }

  func testFaceRerankerStopsWhenLaterCandidateCannotOvertake() async throws {
    let candidates = try tiedCandidates(scores: [0.80, 0.78, 0.70])
    let analyzer = StubFaceAnalyzer(
      results: [
        .success(
          FaceAnalysis(
            faceBounds: [
              CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
            ]
          )
        )
      ]
    )

    let ranked = try await FaceCandidateReranker(
      analyzer: analyzer,
      options: PosterFrameFaceOptions(
        candidateCount: 3,
        maximumBonus: 0.04
      ),
      performanceRecorder: nil
    ).rank(candidates, analyzeAll: false)

    XCTAssertEqual(ranked.first?.candidate.time.seconds, 1)
    XCTAssertEqual(ranked.first?.faceCompositionBonus, 0.04)
    XCTAssertEqual(analyzer.callCount, 1)
  }

  func testFaceRerankerMatchesCompleteRanking() async throws {
    let candidates = try tiedCandidates(scores: [0.80, 0.79, 0.70])
    let results: [Result<FaceAnalysis, PosterFrameError>] = [
      .success(.none),
      .success(
        FaceAnalysis(
          faceBounds: [
            CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.4)
          ]
        )
      ),
      .success(.none),
    ]
    let earlyAnalyzer = StubFaceAnalyzer(results: results)
    let completeAnalyzer = StubFaceAnalyzer(results: results)
    let options = PosterFrameFaceOptions(
      candidateCount: 3,
      maximumBonus: 0.04
    )

    let early = try await FaceCandidateReranker(
      analyzer: earlyAnalyzer,
      options: options,
      performanceRecorder: nil
    ).rank(candidates, analyzeAll: false)
    let complete = try await FaceCandidateReranker(
      analyzer: completeAnalyzer,
      options: options,
      performanceRecorder: nil
    ).rank(candidates, analyzeAll: true)

    XCTAssertEqual(early.first?.candidate.time, complete.first?.candidate.time)
    XCTAssertEqual(early.first?.faceCompositionBonus, 0.04)
    XCTAssertEqual(earlyAnalyzer.callCount, 2)
    XCTAssertEqual(completeAnalyzer.callCount, 3)
  }

  func testRefinedAndPublicAdjustedScoresUseSameFinalClamp() throws {
    var candidate = try XCTUnwrap(tiedCandidates(scores: [0.99]).first)
    candidate.faceCompositionBonus = 0.04
    candidate.subtitlePenalty = 0.08
    let image = try PixelBufferImageConverter.image(
      from: candidate.candidate.pixelBuffer
    )
    let result = PosterFrameResult(
      image: image,
      time: candidate.candidate.time,
      score: candidate.candidate.score,
      metrics: candidate.candidate.metrics,
      subtitlePenalty: candidate.subtitlePenalty,
      faceCompositionBonus: candidate.faceCompositionBonus
    )

    XCTAssertEqual(candidate.adjustedScore, 0.95, accuracy: 1e-12)
    XCTAssertEqual(result.adjustedScore, candidate.adjustedScore, accuracy: 1e-12)
  }

  private func tiedCandidates(
    scores: [Double]
  ) throws -> [RefinedCandidate] {
    let pixelBuffer = try TestPixelBufferFactory.monochrome(
      width: 16,
      height: 16
    ) { _, _ in 128 }
    let metrics = FrameMetrics(
      meanLuma: 0,
      lumaDeviation: 0,
      entropy: 0,
      sharpness: 0,
      colorfulness: 0,
      visualNoise: 0
    )
    return scores.enumerated().map { index, score in
      RefinedCandidate(
        candidate: EvaluatedCandidate(
          pixelBuffer: pixelBuffer,
          time: CMTime(
            seconds: Double(index + 1),
            preferredTimescale: 600
          ),
          score: score,
          metrics: metrics
        )
      )
    }
  }
}
