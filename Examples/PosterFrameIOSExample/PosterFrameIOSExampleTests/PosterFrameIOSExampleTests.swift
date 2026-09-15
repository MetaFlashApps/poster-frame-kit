import CoreMedia
import Foundation
import PosterFrameKit
import XCTest

final class PosterFrameIOSExampleTests: XCTestCase {
  func testPublicEvaluationRunsInIOSProcess() throws {
    let pixelBuffer = try ExamplePixelBufferFactory.bgra(
      width: 32,
      height: 32
    ) { x, y in
      (x + y).isMultiple(of: 2)
        ? (blue: 32, green: 96, red: 224)
        : (blue: 224, green: 160, red: 32)
    }

    let evaluation = try PosterFrameKit.evaluate(
      pixelBuffer: pixelBuffer,
      profile: .general
    )

    XCTAssertGreaterThan(evaluation.score, 0)
    XCTAssertGreaterThan(evaluation.metrics.entropy, 0)
    XCTAssertGreaterThan(evaluation.metrics.colorfulness, 0)
  }

  func testPublicURLSelectionDecodesGeneratedH264Video() async throws {
    let url = try await ExampleGeneratedVideo.make()
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try await PosterFrameKit.bestFrame(
      in: url,
      options: PosterFrameOptions(
        maximumFramesExamined: 12,
        profile: .animation,
        outputSize: CGSize(width: 160, height: 90)
      )
    )

    XCTAssertGreaterThan(result.time.seconds, 1)
    XCTAssertGreaterThan(result.score, 0)
    XCTAssertGreaterThan(result.metrics.entropy, 0)
    XCTAssertGreaterThan(result.metrics.sharpness, 0)
    XCTAssertLessThanOrEqual(result.image.width, 160)
    XCTAssertLessThanOrEqual(result.image.height, 90)
  }

  func testOptionalVisionRefinementsCompleteOrFallBackSafelyOnIOS() async throws {
    guard #available(iOS 18, *) else {
      throw XCTSkip("Vision image aesthetics requires iOS 18 or newer.")
    }
    let url = try await ExampleGeneratedVideo.make()
    defer { try? FileManager.default.removeItem(at: url) }

    let result = try await PosterFrameKit.bestFrame(
      in: url,
      options: PosterFrameOptions(
        maximumFramesExamined: 4,
        profile: .animation,
        subtitleAvoidance: PosterFrameSubtitleOptions(candidateCount: 2),
        facePreference: PosterFrameFaceOptions(candidateCount: 2),
        aestheticPreference: PosterFrameAestheticOptions(candidateCount: 4),
        outputSize: CGSize(width: 160, height: 90)
      )
    )

    XCTAssertTrue(result.adjustedScore.isFinite)
    XCTAssertTrue((0...1).contains(result.adjustedScore))
    XCTAssertTrue((0...1).contains(result.subtitlePenalty))
    XCTAssertTrue((0...1).contains(result.faceCompositionBonus))
    if result.aestheticScore == nil {
      XCTAssertNil(result.isUtilityFrame)
      XCTAssertEqual(result.aestheticAdjustment, 0)
    } else {
      XCTAssertNotNil(result.isUtilityFrame)
    }
  }
}
