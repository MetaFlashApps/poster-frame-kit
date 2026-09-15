import XCTest

@testable import PosterFrameKit

final class PosterFrameCancellationTests: XCTestCase {
  func testMapConvertsTaskCancellationToPosterFrameError() async {
    let task = Task {
      try await PosterFrameCancellation.map {
        try await Task.sleep(for: .seconds(10))
        return 1
      }
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

  func testMapPreservesNonCancellationErrors() async {
    do {
      _ =
        try await PosterFrameCancellation.map {
          throw PosterFrameError.invalidDuration
        } as Int
      XCTFail("Expected error")
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .invalidDuration)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testMapPrefersCancellationWhenOperationTranslatesItsOwnError() async {
    let task = Task {
      try await PosterFrameCancellation.map {
        do {
          try await Task.sleep(for: .seconds(10))
        } catch {
          throw PosterFrameError.invalidDuration
        }
      }
    }
    task.cancel()

    do {
      try await task.value
      XCTFail("Expected cancellation")
    } catch let error as PosterFrameError {
      XCTAssertEqual(error, .cancelled)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testRethrowRecognizesBothCancellationRepresentations() {
    for error: any Error in [CancellationError(), PosterFrameError.cancelled] {
      XCTAssertThrowsError(
        try PosterFrameCancellation.rethrowIfNeeded(error)
      ) { thrownError in
        XCTAssertEqual(thrownError as? PosterFrameError, .cancelled)
      }
    }

    XCTAssertNoThrow(
      try PosterFrameCancellation.rethrowIfNeeded(
        PosterFrameError.invalidDuration
      )
    )
  }
}
