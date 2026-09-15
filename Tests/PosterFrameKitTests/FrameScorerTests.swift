import XCTest

@testable import PosterFrameKit

final class FrameScorerTests: XCTestCase {
  func testBlackAndWhiteFramesReceiveZeroScore() {
    let black = metrics(meanLuma: 0)
    let white = metrics(meanLuma: 1)

    XCTAssertEqual(FrameScorer.score(metrics: black, profile: .general), 0)
    XCTAssertEqual(FrameScorer.score(metrics: white, profile: .general), 0)
  }

  func testDetailedFrameOutranksFlatFrame() {
    let flat = metrics(meanLuma: 0.5, colorfulness: 0.5)
    let detailed = FrameMetrics(
      meanLuma: 0.5,
      lumaDeviation: 0.25,
      entropy: 0.75,
      sharpness: 0.5,
      colorfulness: 0.25,
      visualNoise: 0
    )

    XCTAssertGreaterThan(
      FrameScorer.score(metrics: detailed, profile: .general),
      FrameScorer.score(metrics: flat, profile: .general)
    )
  }

  func testAnimationProfileRewardsSharpnessMoreStrongly() {
    let sharpFrame = FrameMetrics(
      meanLuma: 0.5,
      lumaDeviation: 0,
      entropy: 0.1,
      sharpness: 1,
      colorfulness: 0,
      visualNoise: 0
    )

    XCTAssertGreaterThan(
      FrameScorer.score(metrics: sharpFrame, profile: .animation),
      FrameScorer.score(metrics: sharpFrame, profile: .general)
    )
  }

  func testEveryBuiltInProfileUsesItsDocumentedWeights() {
    XCTAssertEqual(
      ProfileWeights.weights(for: .general),
      PosterFrameWeights(
        sharpness: 0.35,
        contrast: 0.25,
        entropy: 0.30,
        colorfulness: 0.10
      )
    )
    XCTAssertEqual(
      ProfileWeights.weights(for: .animation),
      PosterFrameWeights(
        sharpness: 0.40,
        contrast: 0.30,
        entropy: 0.25,
        colorfulness: 0.05
      )
    )
    let custom = PosterFrameWeights(
      sharpness: 0.1,
      contrast: 0.2,
      entropy: 0.3,
      colorfulness: 0.4
    )
    XCTAssertEqual(ProfileWeights.weights(for: .custom(custom)), custom)
  }

  func testStrongVisualNoiseCannotWinByInflatingEntropyAndSharpness() {
    let structured = FrameMetrics(
      meanLuma: 0.5,
      lumaDeviation: 0.22,
      entropy: 0.72,
      sharpness: 0.12,
      colorfulness: 0.16,
      visualNoise: 0
    )
    let noisy = FrameMetrics(
      meanLuma: 0.5,
      lumaDeviation: 0.28,
      entropy: 0.92,
      sharpness: 0.20,
      colorfulness: 0.05,
      visualNoise: 1
    )
    let unpenalizedNoise = FrameMetrics(
      meanLuma: noisy.meanLuma,
      lumaDeviation: noisy.lumaDeviation,
      entropy: noisy.entropy,
      sharpness: noisy.sharpness,
      colorfulness: noisy.colorfulness,
      visualNoise: 0
    )

    XCTAssertGreaterThan(
      FrameScorer.score(metrics: structured, profile: .animation),
      FrameScorer.score(metrics: noisy, profile: .animation)
    )
    XCTAssertGreaterThan(
      FrameScorer.score(metrics: unpenalizedNoise, profile: .animation),
      FrameScorer.score(metrics: noisy, profile: .animation)
    )
  }

  func testStructuredFrameOutranksSmoothHighEntropyGradient() throws {
    let gradient = try TestPixelBufferFactory.monochrome(
      width: 160,
      height: 90
    ) { x, _ in
      UInt8(x * 255 / 159)
    }
    let structured = try TestPixelBufferFactory.monochrome(
      width: 160,
      height: 90
    ) { x, y in
      let containsSubject = (40..<120).contains(x) && (18..<72).contains(y)
      return containsSubject ? 224 : 32
    }

    var analyzer = FrameAnalyzer()
    let gradientMetrics = try analyzer.analyze(gradient)
    let structuredMetrics = try analyzer.analyze(structured)

    XCTAssertGreaterThan(gradientMetrics.entropy, structuredMetrics.entropy)
    XCTAssertGreaterThan(structuredMetrics.sharpness, gradientMetrics.sharpness)
    let failureMessage = "gradient entropy=\(gradientMetrics.entropy) "
      + "sharpness=\(gradientMetrics.sharpness); structured entropy="
      + "\(structuredMetrics.entropy) sharpness=\(structuredMetrics.sharpness)"
    for profile: PosterFrameProfile in [
      .general, .animation,
    ] {
      XCTAssertGreaterThan(
        FrameScorer.score(metrics: structuredMetrics, profile: profile),
        FrameScorer.score(metrics: gradientMetrics, profile: profile),
        "A smooth gradient must not outrank structured content for \(profile); "
          + failureMessage
      )
    }
  }

  private func metrics(
    meanLuma: Double,
    colorfulness: Double = 0
  ) -> FrameMetrics {
    FrameMetrics(
      meanLuma: meanLuma,
      lumaDeviation: 0,
      entropy: 0,
      sharpness: 0,
      colorfulness: colorfulness,
      visualNoise: 0
    )
  }
}
