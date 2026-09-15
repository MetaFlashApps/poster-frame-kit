import Foundation
import XCTest

@testable import PosterFrameKit

final class PosterFramePerformanceRecorderTests: XCTestCase {
  func testSnapshotAccumulatesEveryStageAndConcurrencyCounter() async throws {
    let recorder = PosterFramePerformanceRecorder()

    await recorder.recordMetadata(.milliseconds(1))
    await recorder.decodeStarted()
    await recorder.decodeStarted()
    await recorder.decodeFinished(after: .milliseconds(2))
    await recorder.decodeFinished(after: .milliseconds(3))
    await recorder.recordImageConversion(.milliseconds(4))
    await recorder.recordAnalysisAndRanking(.milliseconds(5))
    await recorder.recordResultImageConversion(.milliseconds(6))
    await recorder.recordSubtitleAnalysis(
      .milliseconds(7),
      usedAccurateRecognition: false
    )
    await recorder.recordSubtitleAnalysis(
      .milliseconds(8),
      usedAccurateRecognition: true
    )
    await recorder.recordFaceAnalysis(.milliseconds(9))
    await recorder.recordAestheticAnalysis(.milliseconds(10))

    let snapshot = await recorder.snapshot()

    XCTAssertEqual(snapshot.metadataMilliseconds, 1, accuracy: 1e-9)
    XCTAssertEqual(snapshot.seekAndDecodeMilliseconds, 5, accuracy: 1e-9)
    XCTAssertEqual(snapshot.imageConversionMilliseconds, 4, accuracy: 1e-9)
    XCTAssertEqual(snapshot.analysisAndRankingMilliseconds, 5, accuracy: 1e-9)
    XCTAssertEqual(snapshot.resultImageConversionMilliseconds, 6, accuracy: 1e-9)
    XCTAssertEqual(snapshot.subtitleAnalysisMilliseconds, 15, accuracy: 1e-9)
    XCTAssertEqual(snapshot.faceAnalysisMilliseconds, 9, accuracy: 1e-9)
    XCTAssertEqual(snapshot.aestheticAnalysisMilliseconds, 10, accuracy: 1e-9)
    XCTAssertEqual(snapshot.decodedFrameCount, 2)
    XCTAssertEqual(snapshot.analyzedFrameCount, 1)
    XCTAssertEqual(snapshot.subtitleAnalyzedFrameCount, 2)
    XCTAssertEqual(snapshot.subtitleAccurateFallbackCount, 1)
    XCTAssertEqual(snapshot.faceAnalyzedFrameCount, 1)
    XCTAssertEqual(snapshot.aestheticAnalyzedFrameCount, 1)
    XCTAssertEqual(snapshot.peakConcurrentDecodes, 2)

    let encoded = try JSONEncoder().encode(snapshot)
    XCTAssertEqual(
      try JSONDecoder().decode(
        PosterFramePerformanceSnapshot.self,
        from: encoded
      ),
      snapshot
    )
  }
}
