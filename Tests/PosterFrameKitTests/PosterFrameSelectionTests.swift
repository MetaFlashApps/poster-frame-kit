import CoreGraphics
import CoreMedia
import XCTest

@testable import PosterFrameKit

final class PosterFrameSelectionTests: XCTestCase {
  func testSelectionChoosesDetailedCandidateAndForwardsOutputSize() async throws {
    let flat = try TestPixelBufferFactory.bgra(width: 32, height: 16) { _, _ in
      (blue: 0, green: 0, red: 0)
    }
    let detailed = try TestPixelBufferFactory.bgra(width: 32, height: 16) { x, _ in
      x < 16
        ? (blue: 0, green: 0, red: 0)
        : (blue: 255, green: 255, red: 255)
    }
    let source = StubFrameSource(
      duration: CMTime(seconds: 10, preferredTimescale: 600),
      samples: [
        sample(flat, requested: 1, actual: 1),
        sample(detailed, requested: 9, actual: 9),
      ]
    )
    let outputSize = CGSize(width: 640, height: 360)

    let result = try await PosterFrameKit.bestFrame(
      from: source,
      options: PosterFrameOptions(
        searchRange: 0.1...0.9,
        maximumFramesExamined: 2,
        outputSize: outputSize
      )
    )

    let requestedMaximumSizes = await source.requestedMaximumSizes
    XCTAssertEqual(result.time.seconds, 9)
    XCTAssertGreaterThan(result.score, 0)
    XCTAssertEqual(requestedMaximumSizes, [outputSize, outputSize])
  }

  func testDuplicateActualTimesAreEvaluatedOnlyOnce() async throws {
    let first = try TestPixelBufferFactory.bgra(width: 8, height: 8) { _, _ in
      (blue: 255, green: 255, red: 255)
    }
    let duplicateWithUnsupportedFormat = try TestPixelBufferFactory.unsupported(
      width: 8,
      height: 8
    )
    let source = StubFrameSource(
      duration: CMTime(seconds: 2, preferredTimescale: 600),
      samples: [
        sample(first, requested: 0.2, actual: 1),
        sample(duplicateWithUnsupportedFormat, requested: 1.8, actual: 1),
      ]
    )

    let result = try await PosterFrameKit.bestFrame(
      from: source,
      options: PosterFrameOptions(
        searchRange: 0.1...0.9,
        maximumFramesExamined: 2
      )
    )

    let requestedTimes = await source.requestedTimes
    XCTAssertEqual(result.time.seconds, 1)
    XCTAssertEqual(requestedTimes.count, 2)
  }

  func testEqualScoresResolveToEarlierActualTime() async throws {
    let frame = try TestPixelBufferFactory.bgra(width: 8, height: 8) { x, _ in
      x < 4
        ? (blue: 0, green: 0, red: 0)
        : (blue: 255, green: 255, red: 255)
    }
    let source = StubFrameSource(
      duration: CMTime(seconds: 10, preferredTimescale: 600),
      samples: [
        sample(frame, requested: 1, actual: 8),
        sample(frame, requested: 9, actual: 2),
      ]
    )

    let result = try await PosterFrameKit.bestFrame(
      from: source,
      options: PosterFrameOptions(maximumFramesExamined: 2)
    )

    XCTAssertEqual(result.time.seconds, 2)
  }

  func testCancelledTaskReturnsPosterFrameCancellation() async {
    let task = Task {
      try await PosterFrameKit.bestFrame(
        from: StubFrameSource(duration: .positiveInfinity, samples: [])
      )
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

  func testEmptySourceReturnsNoCandidateFrames() async {
    let source = StubFrameSource(
      duration: CMTime(seconds: 1, preferredTimescale: 600),
      samples: []
    )

    do {
      _ = try await PosterFrameKit.bestFrame(
        from: source,
        options: PosterFrameOptions(maximumFramesExamined: 1)
      )
      XCTFail("Expected an empty-source error")
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .noCandidateFrames)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testInvalidActualTimeIsSkippedWithoutCreatingACandidate() async throws {
    let frame = try TestPixelBufferFactory.bgra(width: 8, height: 8) { _, _ in
      (blue: 128, green: 128, red: 128)
    }
    let source = StubFrameSource(
      duration: CMTime(seconds: 1, preferredTimescale: 600),
      samples: [
        PosterFrameSample(
          pixelBuffer: frame,
          requestedTime: .zero,
          actualTime: .invalid
        )
      ]
    )

    do {
      _ = try await PosterFrameKit.bestFrame(
        from: source,
        options: PosterFrameOptions(maximumFramesExamined: 1)
      )
      XCTFail("Expected an empty-candidate error")
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .noCandidateFrames)
    }
  }

  func testDurationAndFrameCancellationUsePublicCancellationError() async {
    await assertSelectionCancelled(
      from: ThrowingFrameSource(durationFailure: .cancellation)
    )
    await assertSelectionCancelled(
      from: ThrowingFrameSource(frameFailure: .cancellation)
    )
    await assertSelectionCancelled(
      from: ThrowingFrameSource(frameFailure: .posterFrame(.cancelled))
    )
  }

  func testInvalidOptionsFailBeforeSourceIsRequested() async {
    let source = StubFrameSource(
      duration: CMTime(seconds: 1, preferredTimescale: 600),
      samples: []
    )

    do {
      _ = try await PosterFrameKit.bestFrame(
        from: source,
        options: PosterFrameOptions(maximumFramesExamined: 0)
      )
      XCTFail("Expected invalid options")
    } catch let error as PosterFrameError {
      guard case .invalidOptions = error else {
        return XCTFail("Unexpected PosterFrameError: \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    let requestedTimes = await source.requestedTimes
    XCTAssertEqual(requestedTimes, [])
  }

  private func assertSelectionCancelled(
    from source: any PosterFrameSource,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      _ = try await PosterFrameKit.bestFrame(from: source)
      XCTFail("Expected cancellation", file: file, line: line)
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .cancelled, file: file, line: line)
    } catch {
      XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
  }

}
