import CoreMedia
import PosterFrameKit
import XCTest
@testable import PosterFrameIOSExample

final class ExamplePresentationTests: XCTestCase {
  func testTimestampFormatterUsesHoursMinutesSecondsAndMilliseconds() {
    let time = CMTime(seconds: 3_723.125, preferredTimescale: 1_000)

    XCTAssertEqual(
      ExampleTimestampFormatter.string(from: time),
      "01:02:03.125"
    )
    XCTAssertNil(ExampleTimestampFormatter.string(from: .invalid))
  }

  func testMetricPresentationIncludesEveryPublicBaseMetric() {
    let metrics = FrameMetrics(
      meanLuma: 0.1,
      lumaDeviation: 0.2,
      entropy: 0.3,
      sharpness: 0.4,
      colorfulness: 0.5,
      visualNoise: 0.6
    )

    let presentation = ExampleMetric.all(from: metrics)

    XCTAssertEqual(presentation.map(\.title), [
      "Luma",
      "Contrast",
      "Entropy",
      "Sharpness",
      "Colorfulness",
      "Visual Noise",
    ])
    XCTAssertEqual(presentation.map(\.value), [0.1, 0.2, 0.3, 0.4, 0.5, 0.6])
  }
}
