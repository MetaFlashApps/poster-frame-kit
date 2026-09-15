import XCTest

@testable import PosterFrameKit

final class PosterFrameErrorTests: XCTestCase {
  func testEveryErrorHasAStablePresentationDescription() {
    let cases: [(PosterFrameError, String)] = [
      (
        .invalidOptions("candidateCount"),
        "Invalid poster-frame options: candidateCount."
      ),
      (.unsupportedVideo, "The video could not be decoded."),
      (.noVideoTrack, "The file does not contain a video track."),
      (
        .invalidDuration,
        "The video does not have a finite, positive duration."
      ),
      (
        .noCandidateFrames,
        "No candidate frames could be decoded and analyzed."
      ),
      (
        .invalidPixelBuffer,
        "A decoded frame contains invalid pixel data."
      ),
      (
        .unsupportedPixelFormat(875_704_438),
        "The decoded pixel format 875704438 is not supported."
      ),
      (
        .imageCreationFailed,
        "The selected frame could not be converted to an image."
      ),
      (.cancelled, "Poster-frame selection was cancelled."),
    ]

    for (error, expectedDescription) in cases {
      XCTAssertEqual(error.errorDescription, expectedDescription)
    }
  }
}
