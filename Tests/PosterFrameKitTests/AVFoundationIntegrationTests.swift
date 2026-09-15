import CoreMedia
import CoreVideo
import Foundation
import XCTest

@testable import PosterFrameKit

final class AVFoundationIntegrationTests: XCTestCase {
  func testPublicFrameSourceCachesDurationAndClampsDecodeRequests() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let source = AVFoundationFrameSource(url: url)

    let duration = try await source.duration
    let cachedDuration = try await source.duration
    XCTAssertEqual(cachedDuration, duration)

    let beforeStart = try await source.frame(
      at: CMTime(seconds: -1, preferredTimescale: 600),
      maximumSize: nil
    )
    XCTAssertEqual(beforeStart.requestedTime.seconds, -1)
    XCTAssertGreaterThanOrEqual(beforeStart.actualTime.seconds, 0)

    let afterEnd = try await source.frame(
      at: CMTimeAdd(
        duration,
        CMTime(seconds: 1, preferredTimescale: 600)
      ),
      maximumSize: CGSize(width: 80, height: 45)
    )
    XCTAssertGreaterThanOrEqual(afterEnd.actualTime.seconds, 0)
    XCTAssertLessThan(afterEnd.actualTime.seconds, duration.seconds)
    XCTAssertLessThanOrEqual(CVPixelBufferGetWidth(afterEnd.pixelBuffer), 80)
    XCTAssertLessThanOrEqual(CVPixelBufferGetHeight(afterEnd.pixelBuffer), 45)
  }

  func testGeneratedVideoProducesDetailedPosterFrame() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }

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

  func testEndPositionReturnsLastDecodableFrame() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let result = try await PosterFrameKit.bestFrame(
      in: url,
      options: PosterFrameOptions(
        searchRange: 1...1,
        maximumFramesExamined: 1,
        outputSize: CGSize(width: 160, height: 90)
      )
    )

    XCTAssertGreaterThan(result.time.seconds, 1.5)
    XCTAssertGreaterThan(result.metrics.entropy, 0)
  }

  func testBoundedDecoderLanesPreserveSelection() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let options = PosterFrameOptions(
      maximumFramesExamined: 12,
      profile: .animation,
      outputSize: CGSize(width: 160, height: 90)
    )

    let sequential = try await PosterFrameKit.benchmarkBestFrame(
      in: url,
      options: options,
      decoderLaneCount: 1
    )
    for laneCount in [2, 3, 4] {
      let concurrent = try await PosterFrameKit.benchmarkBestFrame(
        in: url,
        options: options,
        decoderLaneCount: laneCount
      )

      XCTAssertEqual(
        CMTimeCompare(concurrent.result.time, sequential.result.time),
        0
      )
      XCTAssertEqual(concurrent.result.score, sequential.result.score)
      XCTAssertEqual(concurrent.result.metrics, sequential.result.metrics)
      XCTAssertEqual(concurrent.result.image.width, sequential.result.image.width)
      XCTAssertEqual(concurrent.result.image.height, sequential.result.image.height)
      XCTAssertGreaterThan(concurrent.performance.peakConcurrentDecodes, 0)
      XCTAssertLessThanOrEqual(
        concurrent.performance.peakConcurrentDecodes,
        laneCount
      )
    }

    let publicResult = try await PosterFrameKit.bestFrame(
      in: url,
      options: options
    )
    let recommended = try await PosterFrameKit.benchmarkBestFrame(
      in: url,
      options: options,
      decoderLaneCount: PosterFrameKit.recommendedAVFoundationDecoderLaneCount
    )
    XCTAssertEqual(CMTimeCompare(publicResult.time, recommended.result.time), 0)
    XCTAssertEqual(publicResult.score, recommended.result.score)
    XCTAssertEqual(publicResult.metrics, recommended.result.metrics)
  }

  func testGeneratedVideoRunsAestheticPreferenceOnSupportedSystems() async throws {
    guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *) else {
      throw XCTSkip("Vision image aesthetics is unavailable.")
    }
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let selection = try await PosterFrameKit.benchmarkBestFrame(
      in: url,
      options: PosterFrameOptions(
        maximumFramesExamined: 4,
        profile: .animation,
        aestheticPreference: PosterFrameAestheticOptions(
          candidateCount: 4
        ),
        outputSize: CGSize(width: 160, height: 90)
      ),
      decoderLaneCount: 1
    )

    XCTAssertNotNil(selection.result.aestheticScore)
    XCTAssertNotNil(selection.result.isUtilityFrame)
    XCTAssertGreaterThan(
      selection.performance.aestheticAnalyzedFrameCount,
      0
    )
    XCTAssertGreaterThan(
      selection.performance.aestheticAnalysisMilliseconds,
      0
    )
  }

  func testCancelledURLSelectionReturnsPosterFrameCancellation() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let task = Task {
      try await PosterFrameKit.bestFrame(in: url)
    }
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .cancelled)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}
