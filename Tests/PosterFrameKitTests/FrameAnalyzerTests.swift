import XCTest

@testable import PosterFrameKit

final class FrameAnalyzerTests: XCTestCase {
  func testUniformLumaHasExpectedMeanAndNoInformation() throws {
    let buffer = try TestPixelBufferFactory.monochrome(
      width: 16,
      height: 16
    ) { _, _ in 128 }

    var analyzer = FrameAnalyzer()
    let metrics = try analyzer.analyze(buffer)

    XCTAssertEqual(metrics.meanLuma, 128.0 / 255, accuracy: 1e-12)
    XCTAssertEqual(metrics.lumaDeviation, 0, accuracy: 1e-12)
    XCTAssertEqual(metrics.entropy, 0, accuracy: 1e-12)
    XCTAssertEqual(metrics.sharpness, 0, accuracy: 1e-12)
    XCTAssertEqual(metrics.colorfulness, 0, accuracy: 1e-12)
    XCTAssertEqual(metrics.visualNoise, 0, accuracy: 1e-12)
  }

  func testTwoToneEdgeProducesContrastEntropyAndSharpness() throws {
    let buffer = try TestPixelBufferFactory.monochrome(
      width: 32,
      height: 16
    ) { x, _ in
      x < 16 ? 0 : 255
    }

    var analyzer = FrameAnalyzer()
    let metrics = try analyzer.analyze(buffer)

    XCTAssertEqual(metrics.meanLuma, 0.5, accuracy: 1e-12)
    XCTAssertEqual(metrics.lumaDeviation, 0.5, accuracy: 1e-12)
    XCTAssertEqual(metrics.entropy, 0.125, accuracy: 1e-12)
    XCTAssertGreaterThan(metrics.sharpness, 0)
    XCTAssertLessThanOrEqual(metrics.sharpness, 1)
    XCTAssertEqual(metrics.visualNoise, 0, accuracy: 1e-12)
  }

  func testDenseDeterministicNoiseProducesStrongVisualNoiseMetric() throws {
    let buffer = try TestPixelBufferFactory.monochrome(
      width: 160,
      height: 90
    ) { x, y in
      var hash = UInt64(x) &* 0x9E37_79B1
      hash ^= UInt64(y) &* 0x85EB_CA77
      hash ^= hash >> 16
      hash &*= 0xC2B2_AE3D
      hash ^= hash >> 13
      return UInt8(truncatingIfNeeded: hash)
    }

    var analyzer = FrameAnalyzer()
    let metrics = try analyzer.analyze(buffer)

    XCTAssertGreaterThan(metrics.visualNoise, 0.8)
    XCTAssertGreaterThan(metrics.entropy, 0)
    XCTAssertGreaterThan(metrics.sharpness, 0)
  }

  func testPackedColorProducesDeterministicLumaAndColorfulness() throws {
    let buffer = try TestPixelBufferFactory.bgra(
      width: 8,
      height: 8
    ) { _, _ in
      (blue: 0, green: 0, red: 255)
    }

    var analyzer = FrameAnalyzer()
    let metrics = try analyzer.analyze(buffer)

    XCTAssertEqual(metrics.meanLuma, 54.0 / 255, accuracy: 1e-12)
    XCTAssertEqual(metrics.colorfulness, 1, accuracy: 1e-12)
  }

  func testARGBUsesItsDocumentedChannelOrder() throws {
    let argb = try TestPixelBufferFactory.argb(width: 4, height: 4) { _, _ in
      (red: 255, green: 0, blue: 0)
    }

    var buffer = AnalysisBuffer()
    try buffer.load(from: argb)
    XCTAssertEqual(buffer.luma[0], 54)
    XCTAssertEqual(buffer.colorfulness, 1, accuracy: 1e-12)
  }

  func testPackedLayoutsMapChannelsAtUnsafeMemoryBoundary() {
    let bytes: [UInt8] = [10, 20, 30, 40]

    bytes.withUnsafeBufferPointer { buffer in
      guard let address = buffer.baseAddress else {
        return XCTFail("Expected a non-empty byte buffer")
      }

      let argb = PackedPixelLayout.argb.channels(from: address)
      XCTAssertEqual(argb.red, 20)
      XCTAssertEqual(argb.green, 30)
      XCTAssertEqual(argb.blue, 40)

      let bgra = PackedPixelLayout.bgra.channels(from: address)
      XCTAssertEqual(bgra.red, 30)
      XCTAssertEqual(bgra.green, 20)
      XCTAssertEqual(bgra.blue, 10)

      let rgba = PackedPixelLayout.rgba.channels(from: address)
      XCTAssertEqual(rgba.red, 10)
      XCTAssertEqual(rgba.green, 20)
      XCTAssertEqual(rgba.blue, 30)
    }
  }

  func testBiPlanarFullRangePreservesLumaAndNeutralChroma() throws {
    let pixelBuffer = try TestPixelBufferFactory.biPlanar420(
      width: 4,
      height: 4,
      videoRange: false,
      luma: { x, _ in x < 2 ? 32 : 224 },
      chroma: { _, _ in (cb: 128, cr: 128) }
    )

    var buffer = AnalysisBuffer()
    try buffer.load(from: pixelBuffer)

    XCTAssertEqual(buffer.width, 4)
    XCTAssertEqual(buffer.height, 4)
    XCTAssertEqual(Array(buffer.luma.prefix(4)), [32, 32, 224, 224])
    XCTAssertEqual(buffer.colorfulness, 0, accuracy: 1e-12)
  }

  func testBiPlanarVideoRangeExpandsLumaAndNormalizesChroma() throws {
    let pixelBuffer = try TestPixelBufferFactory.biPlanar420(
      width: 4,
      height: 4,
      videoRange: true,
      luma: { x, _ in x < 2 ? 0 : 255 },
      chroma: { _, _ in (cb: 240, cr: 128) }
    )

    var buffer = AnalysisBuffer()
    try buffer.load(from: pixelBuffer)

    XCTAssertEqual(Array(buffer.luma.prefix(4)), [0, 0, 255, 255])
    XCTAssertEqual(buffer.colorfulness, 1 / sqrt(2), accuracy: 1e-12)
  }

  func testPublicEvaluationReturnsNormalizedScore() throws {
    let buffer = try TestPixelBufferFactory.bgra(
      width: 16,
      height: 16
    ) { x, _ in
      x < 8
        ? (blue: 0, green: 0, red: 0)
        : (blue: 255, green: 255, red: 255)
    }

    let evaluation = try PosterFrameKit.evaluate(
      pixelBuffer: buffer,
      profile: .animation
    )

    XCTAssertGreaterThan(evaluation.score, 0)
    XCTAssertLessThanOrEqual(evaluation.score, 1)
    XCTAssertEqual(evaluation.metrics.meanLuma, 0.5, accuracy: 1e-12)
  }

  func testUnsupportedPixelFormatProducesDocumentedError() throws {
    let buffer = try TestPixelBufferFactory.unsupported(width: 8, height: 8)

    var analyzer = FrameAnalyzer()
    XCTAssertThrowsError(try analyzer.analyze(buffer)) { error in
      XCTAssertEqual(
        error as? PosterFrameError,
        .unsupportedPixelFormat(kCVPixelFormatType_422YpCbCr8)
      )
    }
  }
}
