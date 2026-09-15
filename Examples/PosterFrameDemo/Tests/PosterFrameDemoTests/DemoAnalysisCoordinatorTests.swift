import Foundation
import PosterFrameKit
import XCTest

@testable import PosterFrameDemo

@MainActor
final class DemoAnalysisCoordinatorTests: XCTestCase {
  func testGeneratedVideoProducesSelectionAndBoundedDisplayFrames() async throws {
    let url = try await GeneratedDemoVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let options = PosterFrameOptions(
      maximumFramesExamined: 8,
      profile: .animation,
      outputSize: CGSize(width: 320, height: 180)
    )
    var progress: [DemoAnalysisProgress] = []

    let output = try await DemoAnalysisCoordinator.run(
      videoURL: url,
      options: options,
      comparisonCaptureOptions: options
    ) { update in
      progress.append(update)
    }

    guard let firstProgress = progress.first,
      case .selected(let selection, let selectionDuration) = firstProgress
    else {
      return XCTFail("Expected the selected frame before comparison work")
    }
    XCTAssertGreaterThan(selection.image.width, 0)
    XCTAssertGreaterThan(selectionDuration, .zero)
    XCTAssertTrue(progress.contains { update in
      if case .stage(.comparisonCapture) = update {
        true
      } else {
        false
      }
    })
    XCTAssertNil(output.comparisonErrorMessage)
    XCTAssertNotNil(output.comparisonCaptureDuration)
    XCTAssertFalse(output.candidateFrames.isEmpty)
    XCTAssertLessThanOrEqual(output.candidateFrames.count, 8)
    XCTAssertTrue(
      output.candidateFrames.allSatisfy {
        $0.thumbnail.width <= 360 && $0.thumbnail.height <= 203
      }
    )

    if #available(macOS 15.0, *) {
      XCTAssertTrue(progress.contains { update in
        if case .stage(.vision) = update {
          true
        } else {
          false
        }
      })
      XCTAssertNotNil(output.visionDuration)
      XCTAssertNotNil(output.visionResult)
      XCTAssertNotNil(output.hybridResult)
    }
  }
}
