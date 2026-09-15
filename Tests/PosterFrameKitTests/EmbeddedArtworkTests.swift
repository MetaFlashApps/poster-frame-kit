import Foundation
import XCTest

@testable import PosterFrameKit

final class EmbeddedArtworkTests: XCTestCase {
  func testGeneratedVideoReturnsEmbeddedArtwork() async throws {
    let url = try await GeneratedVideoFixture.make(artworkData: Self.pngData)
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let artwork = try await PosterFrameKit.embeddedArtwork(in: url)

    XCTAssertEqual(artwork?.width, 1)
    XCTAssertEqual(artwork?.height, 1)
  }

  func testGeneratedVideoWithoutArtworkReturnsNil() async throws {
    let url = try await GeneratedVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let artwork = try await PosterFrameKit.embeddedArtwork(in: url)

    XCTAssertNil(artwork)
  }

  func testInvalidEmbeddedArtworkReturnsNil() async throws {
    let url = try await GeneratedVideoFixture.make(
      artworkData: Data("not an image".utf8)
    )
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let artwork = try await PosterFrameKit.embeddedArtwork(in: url)

    XCTAssertNil(artwork)
  }

  func testCancelledArtworkLookupReturnsPosterFrameCancellation() async throws {
    let url = try await GeneratedVideoFixture.make(artworkData: Self.pngData)
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let task = Task {
      try await PosterFrameKit.embeddedArtwork(in: url)
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

  private static let pngData = Data(
    base64Encoded:
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )!
}
