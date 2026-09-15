import CoreMedia

@testable import PosterFrameKit

actor ThrowingFrameSource: PosterFrameSource {
  enum Failure: Sendable {
    case cancellation
    case posterFrame(PosterFrameError)

    func throwError() throws -> Never {
      switch self {
      case .cancellation:
        throw CancellationError()
      case .posterFrame(let error):
        throw error
      }
    }
  }

  let sourceDuration: CMTime
  let durationFailure: Failure?
  let frameFailure: Failure

  init(
    duration: CMTime = CMTime(seconds: 1, preferredTimescale: 600),
    durationFailure: Failure? = nil,
    frameFailure: Failure = .posterFrame(.noCandidateFrames)
  ) {
    sourceDuration = duration
    self.durationFailure = durationFailure
    self.frameFailure = frameFailure
  }

  var duration: CMTime {
    get async throws {
      if let durationFailure {
        try durationFailure.throwError()
      }
      return sourceDuration
    }
  }

  func frame(
    at time: CMTime,
    maximumSize: CGSize?
  ) async throws -> PosterFrameSample {
    try frameFailure.throwError()
  }
}
