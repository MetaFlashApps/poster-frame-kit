import PosterFrameKit
import XCTest

@testable import PosterFrameDemo

@MainActor
final class DemoViewModelTests: XCTestCase {
  func testProfilePresentationAndMappingRemainStable() {
    XCTAssertEqual(DemoProfile.general.id, .general)
    XCTAssertEqual(DemoProfile.general.title, "General")
    XCTAssertEqual(DemoProfile.general.posterFrameProfile, .general)
    XCTAssertEqual(DemoProfile.animation.id, .animation)
    XCTAssertEqual(DemoProfile.animation.title, "Animation")
    XCTAssertEqual(DemoProfile.animation.posterFrameProfile, .animation)
  }

  func testEmptyAndReadyStateDescriptions() {
    let viewModel = DemoViewModel()

    XCTAssertNil(viewModel.selectedFileName)
    XCTAssertFalse(viewModel.canRunAnalysis)
    XCTAssertNil(viewModel.performanceComparison)
    XCTAssertEqual(viewModel.visionEmptyTitle, "No Video Selected")
    XCTAssertEqual(viewModel.visionEmptyDescription, "Choose a video.")

    viewModel.selectedURL = URL(filePath: "/tmp/example.mp4")
    XCTAssertEqual(viewModel.selectedFileName, "example.mp4")
    XCTAssertTrue(viewModel.canRunAnalysis)
    if viewModel.isVisionAvailable {
      XCTAssertEqual(viewModel.visionEmptyTitle, "Not Compared Yet")
      XCTAssertEqual(
        viewModel.visionEmptyDescription,
        "The automatic comparison has not produced a Vision result yet."
      )
    }

    viewModel.visionErrorMessage = "Vision test failure"
    if viewModel.isVisionAvailable {
      XCTAssertEqual(viewModel.visionEmptyTitle, "Vision Failed")
      XCTAssertEqual(
        viewModel.visionEmptyDescription,
        "Vision test failure"
      )
    }
  }

  func testErrorPresentationCanBeDismissed() {
    let viewModel = DemoViewModel()

    viewModel.present(DemoFrameError.invalidDuration)
    XCTAssertTrue(viewModel.isShowingError)
    XCTAssertEqual(
      viewModel.errorMessage,
      "The video does not have a usable duration."
    )

    viewModel.dismissError()
    XCTAssertFalse(viewModel.isShowingError)
    XCTAssertNil(viewModel.errorMessage)

    viewModel.present(message: "Direct message")
    XCTAssertTrue(viewModel.isShowingError)
    XCTAssertEqual(viewModel.errorMessage, "Direct message")
  }

  func testPerformanceComparisonRequiresAllDurations() {
    let viewModel = DemoViewModel()
    viewModel.posterFrameDuration = .milliseconds(20)
    viewModel.comparisonCaptureDuration = .milliseconds(10)

    XCTAssertNil(viewModel.performanceComparison)

    viewModel.visionDuration = .milliseconds(5)
    XCTAssertEqual(viewModel.performanceComparison?.winner, .visionPipeline)
  }

  func testUsesMeasuredCandidateBudgetByDefault() {
    let viewModel = DemoViewModel()

    XCTAssertEqual(viewModel.maximumFramesExamined, 24)
    XCTAssertEqual(viewModel.options.maximumFramesExamined, 24)
  }

  func testMidrollExclusionIsEnabledByDefaultAndCanBeDisabled() {
    let viewModel = DemoViewModel()

    XCTAssertEqual(viewModel.options.excludedRanges, [0.46...0.54])

    viewModel.excludesMidroll = false

    XCTAssertTrue(viewModel.options.excludedRanges.isEmpty)
  }

  func testSubtitleAvoidanceIsDisabledByDefaultAndCanBeEnabled() {
    let viewModel = DemoViewModel()

    XCTAssertNil(viewModel.options.subtitleAvoidance)

    viewModel.avoidsSubtitles = true

    XCTAssertEqual(
      viewModel.options.subtitleAvoidance,
      PosterFrameSubtitleOptions()
    )
  }

  func testFacePreferenceIsDisabledByDefaultAndCanBeEnabled() {
    let viewModel = DemoViewModel()

    XCTAssertNil(viewModel.options.facePreference)

    viewModel.prefersFaces = true

    XCTAssertEqual(
      viewModel.options.facePreference,
      PosterFrameFaceOptions()
    )
  }

  func testAestheticPreferenceIsDisabledByDefaultAndCanBeEnabled() {
    let viewModel = DemoViewModel()

    XCTAssertNil(viewModel.options.aestheticPreference)

    viewModel.prefersAesthetics = true

    XCTAssertEqual(
      viewModel.options.aestheticPreference,
      PosterFrameAestheticOptions()
    )
  }

  func testSelectingVideoStartsAnalysisImmediately() {
    let viewModel = DemoViewModel()
    let url = URL(filePath: "/missing/video.mp4")

    viewModel.selectVideo(url)

    XCTAssertEqual(viewModel.selectedURL, url)
    XCTAssertTrue(viewModel.isLoadingBaseline)
    XCTAssertTrue(viewModel.isAnalyzing)
    XCTAssertEqual(viewModel.analysisStage, .posterFrameKit)
    viewModel.cancelAnalysis()
  }

  func testComparisonCaptureUsesSameSamplingWithoutWinnerRefinements() {
    let viewModel = DemoViewModel()
    viewModel.excludesMidroll = false
    viewModel.maximumFramesExamined = 17
    viewModel.profile = .general
    viewModel.avoidsSubtitles = true
    viewModel.prefersFaces = true
    viewModel.prefersAesthetics = true

    var expected = viewModel.options
    expected.subtitleAvoidance = nil
    expected.facePreference = nil
    expected.aestheticPreference = nil

    XCTAssertEqual(viewModel.comparisonCaptureOptions, expected)
  }

  func testChangingOptionsPreservesExistingMeasurementsUntilNextRun() {
    let viewModel = DemoViewModel()
    viewModel.appliedOptions = viewModel.options
    viewModel.posterFrameDuration = .seconds(2)
    viewModel.comparisonCaptureDuration = .seconds(1)

    viewModel.maximumFramesExamined += 1

    XCTAssertEqual(viewModel.posterFrameDuration, .seconds(2))
    XCTAssertEqual(viewModel.comparisonCaptureDuration, .seconds(1))
    XCTAssertTrue(viewModel.hasPendingOptionChanges)
  }

  func testPendingOptionsRemainCurrentWhenRestored() {
    let viewModel = DemoViewModel()
    viewModel.appliedOptions = viewModel.options

    viewModel.avoidsSubtitles = true
    XCTAssertTrue(viewModel.hasPendingOptionChanges)

    viewModel.avoidsSubtitles = false
    XCTAssertFalse(viewModel.hasPendingOptionChanges)
  }

  func testSchedulingAndCancellationExposeAutomaticUpdateState() {
    let viewModel = DemoViewModel()
    viewModel.selectedURL = URL(filePath: "/missing/video.mp4")

    viewModel.scheduleComparison()
    XCTAssertTrue(viewModel.isAutoRunPending)
    XCTAssertFalse(viewModel.canRunAnalysis)

    viewModel.cancelAnalysis()
    XCTAssertFalse(viewModel.isAutoRunPending)
    XCTAssertFalse(viewModel.isAnalyzing)
  }

  func testLoadingStateTracksEachComparisonPhase() {
    let viewModel = DemoViewModel()
    viewModel.isAnalyzing = true
    viewModel.analysisStage = .posterFrameKit

    XCTAssertTrue(viewModel.isPosterFrameLoading)
    XCTAssertEqual(
      viewModel.visionWorkingDescription,
      "Waiting for PosterFrameKit…"
    )

    viewModel.analysisStage = .comparisonCapture
    XCTAssertEqual(
      viewModel.isVisionComparisonLoading,
      viewModel.isVisionAvailable
    )
    XCTAssertEqual(
      viewModel.visionWorkingDescription,
      "Capturing comparison candidates…"
    )
  }

  func testCandidateCaptureHasExplicitProgressTitle() {
    XCTAssertEqual(
      DemoAnalysisStage.comparisonCapture.progressTitle,
      "Capturing candidates for the Vision comparison…"
    )
  }
}
