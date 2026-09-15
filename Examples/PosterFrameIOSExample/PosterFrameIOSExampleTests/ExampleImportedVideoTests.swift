import Foundation
import XCTest
@testable import PosterFrameIOSExample

final class ExampleImportedVideoTests: XCTestCase {
  func testFileBackedImportCreatesAnIndependentTemporaryCopy() throws {
    let sourceURL = URL.temporaryDirectory.appending(
      path: "source-\(UUID().uuidString).mov"
    )
    let contents = Data([0, 1, 2, 3])
    try contents.write(to: sourceURL)
    defer { try? FileManager.default.removeItem(at: sourceURL) }

    let importedVideo = try ExampleImportedVideo.copy(from: sourceURL)
    defer { try? FileManager.default.removeItem(at: importedVideo.url) }

    XCTAssertNotEqual(importedVideo.url, sourceURL)
    XCTAssertEqual(importedVideo.url.pathExtension, "mov")
    XCTAssertEqual(importedVideo.displayName, sourceURL.lastPathComponent)
    XCTAssertEqual(try Data(contentsOf: importedVideo.url), contents)
  }
}
