import XCTest

@testable import PosterFrameKit

extension XCTestCase {
  func assertInvalid(
    _ options: PosterFrameOptions,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try options.normalized(), file: file, line: line) { error in
      guard case PosterFrameError.invalidOptions = error else {
        return XCTFail(
          "Expected PosterFrameError.invalidOptions, got \(error)",
          file: file,
          line: line
        )
      }
    }
  }
}
