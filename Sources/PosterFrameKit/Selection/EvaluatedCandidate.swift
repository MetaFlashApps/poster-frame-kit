import CoreMedia
import CoreVideo

struct EvaluatedCandidate: @unchecked Sendable {
  let pixelBuffer: CVPixelBuffer
  let time: CMTime
  let score: Double
  let metrics: FrameMetrics

  func isPreferred(over current: EvaluatedCandidate?) -> Bool {
    guard let current else {
      return true
    }
    if score != current.score {
      return score > current.score
    }
    return CMTimeCompare(time, current.time) < 0
  }

  func isPreferred(over other: EvaluatedCandidate) -> Bool {
    isPreferred(over: Optional(other))
  }
}
