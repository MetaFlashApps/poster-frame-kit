import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import PosterFrameKit
import XCTest

final class PublicAPIContractTests: XCTestCase {
  func testPublicValueTypesComposeWithoutTestableImport() throws {
    let weights = PosterFrameWeights(
      sharpness: 4,
      contrast: 2,
      entropy: 2,
      colorfulness: 2
    )
    let options = PosterFrameOptions(
      searchRange: 0.1...0.9,
      maximumFramesExamined: 12,
      excludedRanges: [0.45...0.55],
      profile: .custom(weights),
      subtitleAvoidance: PosterFrameSubtitleOptions(),
      facePreference: PosterFrameFaceOptions(),
      aestheticPreference: PosterFrameAestheticOptions(),
      outputSize: CGSize(width: 640, height: 360)
    )

    let normalized = try options.normalized()

    XCTAssertEqual(normalized.maximumFramesExamined, 12)
    XCTAssertEqual(normalized.subtitleAvoidance?.candidateCount, 8)
    XCTAssertEqual(normalized.facePreference?.candidateCount, 8)
    XCTAssertEqual(normalized.aestheticPreference?.candidateCount, 12)
    XCTAssertEqual(normalized.outputSize, CGSize(width: 640, height: 360))
    XCTAssertNotNil(PosterFrameError.invalidDuration.errorDescription)
  }

  func testPublicEvaluationAndSourceSelectionContract() async throws {
    let pixelBuffer = try makePixelBuffer()
    let evaluation = try PosterFrameKit.evaluate(pixelBuffer: pixelBuffer)
    let sample = PosterFrameSample(
      pixelBuffer: pixelBuffer,
      requestedTime: CMTime(seconds: 1, preferredTimescale: 600),
      actualTime: CMTime(seconds: 1, preferredTimescale: 600)
    )
    let source = PublicContractFrameSource(sample: sample)

    let selected = try await PosterFrameKit.bestFrame(
      from: source,
      options: PosterFrameOptions(
        searchRange: 0.5...0.5,
        maximumFramesExamined: 1
      )
    )
    let copiedMetrics = FrameMetrics(
      meanLuma: evaluation.metrics.meanLuma,
      lumaDeviation: evaluation.metrics.lumaDeviation,
      entropy: evaluation.metrics.entropy,
      sharpness: evaluation.metrics.sharpness,
      colorfulness: evaluation.metrics.colorfulness,
      visualNoise: evaluation.metrics.visualNoise
    )
    let copiedResult = PosterFrameResult(
      image: selected.image,
      time: selected.time,
      score: selected.score,
      metrics: copiedMetrics
    )

    XCTAssertEqual(selected.time, CMTime(seconds: 1, preferredTimescale: 600))
    XCTAssertEqual(copiedResult.adjustedScore, selected.adjustedScore)
  }

  func testPublicAVFoundationSourceCanBeConstructed() {
    let source = AVFoundationFrameSource(
      url: URL(fileURLWithPath: "/tmp/poster-frame-kit-api-contract.mp4")
    )

    XCTAssertNotNil(source)
  }

  func testPublicEmbeddedArtworkContract() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let artwork = try await PosterFrameKit.embeddedArtwork(in: url)

    XCTAssertNil(artwork)
  }

  private func makePixelBuffer() throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let attributes =
      [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      ] as CFDictionary
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      4,
      4,
      kCVPixelFormatType_32BGRA,
      attributes,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      throw PosterFrameError.invalidPixelBuffer
    }

    guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
      throw PosterFrameError.invalidPixelBuffer
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw PosterFrameError.invalidPixelBuffer
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    for row in 0..<4 {
      let bytes =
        baseAddress
        .advanced(by: row * bytesPerRow)
        .assumingMemoryBound(to: UInt8.self)
      for column in 0..<4 {
        let offset = column * 4
        bytes[offset] = 64
        bytes[offset + 1] = 128
        bytes[offset + 2] = 192
        bytes[offset + 3] = 255
      }
    }
    return pixelBuffer
  }
}

private actor PublicContractFrameSource: PosterFrameSource {
  let duration = CMTime(seconds: 2, preferredTimescale: 600)
  let sample: PosterFrameSample

  init(sample: PosterFrameSample) {
    self.sample = sample
  }

  func frame(
    at time: CMTime,
    maximumSize: CGSize?
  ) async throws -> PosterFrameSample {
    sample
  }
}
