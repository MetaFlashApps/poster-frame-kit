import CoreMedia
import XCTest

@testable import PosterFrameKit

final class CandidatePoolTests: XCTestCase {
  func testRegistrationRejectsInvalidAndDuplicateActualTimes() {
    var pool = CandidatePool(retainedCandidateCount: 2)
    let time = CMTime(seconds: 1, preferredTimescale: 600)

    XCTAssertFalse(pool.register(actualTime: .invalid))
    XCTAssertTrue(pool.register(actualTime: time))
    XCTAssertFalse(pool.register(actualTime: time))
  }

  func testPoolKeepsBestCandidateAndBoundedLeadingGroup() throws {
    var pool = CandidatePool(retainedCandidateCount: 2)
    let candidates = try [
      candidate(score: 0.3, time: 3),
      candidate(score: 0.8, time: 2),
      candidate(score: 0.8, time: 1),
    ]

    for candidate in candidates {
      pool.insert(candidate)
    }

    XCTAssertEqual(pool.bestCandidate?.time.seconds, 1)
    XCTAssertEqual(
      pool.refinementCandidates.map(\.time.seconds),
      [1, 2]
    )
  }

  func testZeroRetentionKeepsOnlyWinnerMetadata() throws {
    var pool = CandidatePool(retainedCandidateCount: 0)
    pool.insert(try candidate(score: 0.5, time: 1))

    XCTAssertNotNil(pool.bestCandidate)
    XCTAssertTrue(pool.refinementCandidates.isEmpty)
  }

  func testLatestPlannedDecodingErrorWinsRegardlessOfCompletionOrder() {
    var pool = CandidatePool(retainedCandidateCount: 0)
    pool.recordDecodingError(PosterFrameError.invalidDuration, candidateIndex: 4)
    pool.recordDecodingError(PosterFrameError.noCandidateFrames, candidateIndex: 2)

    XCTAssertEqual(pool.lastDecodingError?.candidateIndex, 4)
    XCTAssertEqual(
      pool.lastDecodingError?.error as? PosterFrameError,
      .invalidDuration
    )
  }

  private func candidate(score: Double, time: Double) throws -> EvaluatedCandidate {
    EvaluatedCandidate(
      pixelBuffer: try TestPixelBufferFactory.bgra(width: 2, height: 2) {
        _, _ in (blue: 0, green: 0, red: 0)
      },
      time: CMTime(seconds: time, preferredTimescale: 600),
      score: score,
      metrics: FrameMetrics(
        meanLuma: 0,
        lumaDeviation: 0,
        entropy: 0,
        sharpness: 0,
        colorfulness: 0,
        visualNoise: 0
      )
    )
  }
}
