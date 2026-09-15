import CoreMedia
import CoreVideo
import Foundation
import XCTest

@testable import PosterFrameDemo

@MainActor
final class DemoEndToEndTests: XCTestCase {
  func testBaselineAndCandidateCaptureUseGeneratedVideo() async throws {
    let url = try await GeneratedDemoVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }

    let baseline = try await BaselineFrameLoader.load(from: url)
    XCTAssertEqual(baseline.duration.seconds, 2, accuracy: 0.2)
    XCTAssertGreaterThanOrEqual(baseline.time.seconds, 0)
    XCTAssertLessThan(baseline.time.seconds, baseline.duration.seconds)

    let source = CandidateRecordingFrameSource(url: url)
    let duration = try await source.duration
    let requestedTime = CMTime(seconds: 1, preferredTimescale: 600)
    let first = try await source.frame(
      at: requestedTime,
      maximumSize: CGSize(width: 80, height: 45)
    )
    _ = try await source.frame(
      at: requestedTime,
      maximumSize: CGSize(width: 80, height: 45)
    )
    let samples = await source.samples()

    XCTAssertEqual(duration.seconds, baseline.duration.seconds, accuracy: 0.01)
    XCTAssertEqual(samples.count, 1)
    XCTAssertEqual(samples.first?.actualTime, first.actualTime)
    XCTAssertLessThanOrEqual(CVPixelBufferGetWidth(first.pixelBuffer), 80)
    XCTAssertLessThanOrEqual(CVPixelBufferGetHeight(first.pixelBuffer), 45)
  }

  func testViewModelCompletesGeneratedVideoWorkflow() async throws {
    let url = try await GeneratedDemoVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let viewModel = DemoViewModel()
    viewModel.maximumFramesExamined = 8

    viewModel.selectVideo(url)
    for _ in 0..<500 {
      guard viewModel.isAnalyzing || viewModel.isLoadingBaseline else {
        break
      }
      try await Task.sleep(for: .milliseconds(20))
    }

    XCTAssertFalse(viewModel.isAnalyzing)
    XCTAssertFalse(viewModel.isLoadingBaseline)
    XCTAssertFalse(viewModel.isShowingError)
    XCTAssertEqual(viewModel.selectedFileName, url.lastPathComponent)
    XCTAssertNotNil(viewModel.baselineFrame)
    XCTAssertNotNil(viewModel.selectionResult)
    XCTAssertNotNil(viewModel.appliedOptions)
    XCTAssertTrue(viewModel.canRunAnalysis)
    XCTAssertNotNil(
      viewModel.videoPosition(for: viewModel.selectionResult?.time)
    )
    XCTAssertNotNil(viewModel.posterFrameDetailText)
    XCTAssertFalse(viewModel.candidateFrames.isEmpty)
    XCTAssertLessThanOrEqual(
      viewModel.candidateFrames.count,
      viewModel.maximumFramesExamined
    )
    XCTAssertTrue(
      viewModel.candidateFrames.allSatisfy {
        $0.thumbnail.width <= 360 && $0.thumbnail.height <= 203
      }
    )
    XCTAssertNotNil(viewModel.officialCandidateID)
    XCTAssertEqual(viewModel.browsedCandidateID, viewModel.officialCandidateID)
    XCTAssertNotNil(viewModel.heroImage)
    XCTAssertTrue(viewModel.isHeroRecommendation)

    if let alternative = viewModel.candidateFrames.first(where: {
      $0.id != viewModel.officialCandidateID
    }) {
      viewModel.browseCandidate(alternative.id)
      for _ in 0..<250 where viewModel.isLoadingCandidatePreview {
        try await Task.sleep(for: .milliseconds(20))
      }
      XCTAssertFalse(viewModel.isLoadingCandidatePreview)
      XCTAssertEqual(viewModel.browsedCandidateID, alternative.id)
      XCTAssertFalse(viewModel.isHeroRecommendation)
      XCTAssertNotNil(viewModel.heroImage)
    }

    if viewModel.isVisionAvailable {
      XCTAssertNil(viewModel.visionErrorMessage)
      XCTAssertNotNil(viewModel.visionResult)
      XCTAssertNotNil(viewModel.hybridResult)
      XCTAssertNotNil(viewModel.visionDetailText)
      XCTAssertNotNil(viewModel.hybridDetailText)
      XCTAssertNotNil(viewModel.performanceComparison)
    }
  }

  func testAutomaticUpdateAppliesLatestCandidateBudget() async throws {
    let url = try await GeneratedDemoVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: url)
    }
    let viewModel = DemoViewModel()
    viewModel.maximumFramesExamined = 8
    viewModel.selectVideo(url)
    try await waitForAnalysis(viewModel)

    viewModel.maximumFramesExamined = 16
    viewModel.scheduleComparison()
    XCTAssertTrue(viewModel.isAutoRunPending)
    try await waitForAnalysis(viewModel)

    XCTAssertFalse(viewModel.isAutoRunPending)
    XCTAssertEqual(viewModel.appliedOptions?.maximumFramesExamined, 16)
    XCTAssertFalse(viewModel.candidateFrames.isEmpty)
    XCTAssertLessThanOrEqual(viewModel.candidateFrames.count, 16)
  }

  func testSwitchingVideoCompletesLatestSelection() async throws {
    let firstURL = try await GeneratedDemoVideoFixture.make()
    let secondURL = try await GeneratedDemoVideoFixture.make()
    defer {
      try? FileManager.default.removeItem(at: firstURL)
      try? FileManager.default.removeItem(at: secondURL)
    }
    let viewModel = DemoViewModel()
    viewModel.maximumFramesExamined = 8

    viewModel.selectVideo(firstURL)
    try await Task.sleep(for: .milliseconds(20))
    viewModel.selectVideo(secondURL)
    try await waitForAnalysis(viewModel)

    XCTAssertEqual(viewModel.selectedURL, secondURL)
    XCTAssertNotNil(viewModel.selectionResult)
  }

  private func waitForAnalysis(_ viewModel: DemoViewModel) async throws {
    for _ in 0..<500 {
      guard viewModel.isAnalyzing
        || viewModel.isLoadingBaseline
        || viewModel.isAutoRunPending
      else {
        return
      }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("Timed out while waiting for the automatic comparison")
  }
}
