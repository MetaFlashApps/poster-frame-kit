import CoreMedia
import CoreVideo
import XCTest

@testable import PosterFrameKit

extension XCTestCase {
  func tiedCandidateSource(
    actualTimes: [Double]
  ) throws -> StubFrameSource {
    let frame = try TestPixelBufferFactory.bgra(width: 16, height: 16) { x, _ in
      x < 8
        ? (blue: 0, green: 0, red: 0)
        : (blue: 255, green: 255, red: 255)
    }
    let samples = actualTimes.enumerated().map { index, actualTime in
      sample(frame, requested: Double(index + 1), actual: actualTime)
    }
    return StubFrameSource(
      duration: CMTime(seconds: 10, preferredTimescale: 600),
      samples: samples
    )
  }

  func sample(
    _ pixelBuffer: CVPixelBuffer,
    requested: Double,
    actual: Double
  ) -> PosterFrameSample {
    PosterFrameSample(
      pixelBuffer: pixelBuffer,
      requestedTime: CMTime(seconds: requested, preferredTimescale: 600),
      actualTime: CMTime(seconds: actual, preferredTimescale: 600)
    )
  }
}
