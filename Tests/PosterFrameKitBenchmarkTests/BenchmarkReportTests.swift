import Foundation
import XCTest

@testable import PosterFrameKit
@testable import PosterFrameKitBenchmark

final class BenchmarkReportTests: XCTestCase {
  func testCheckedSubtitleDefaultReportKeepsBoundaryWinner() throws {
    let repositoryRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let report = try JSONDecoder().decode(
      BenchmarkReport.self,
      from: Data(
        contentsOf: repositoryRoot.appending(
          path: "Benchmarks/Reports/m1-pro-macos-15.7.4-subtitle-default-eight.json"
        )
      )
    )

    XCTAssertEqual(report.schemaVersion, 7)
    XCTAssertEqual(report.configuration.subtitleCandidateCount, 8)
    let warmRuns = try XCTUnwrap(report.measurements.first?.processWarmRuns)
    XCTAssertEqual(
      warmRuns.map(\.selectedTimeSeconds),
      Array(repeating: 19.5, count: 5)
    )
    XCTAssertEqual(
      warmRuns.map(\.performance.subtitleAnalyzedFrameCount),
      [2, 2, 2, 2, 2]
    )
    XCTAssertEqual(
      warmRuns.map(\.performance.subtitleAccurateFallbackCount),
      [0, 0, 0, 0, 0]
    )
  }

  func testReportSchemaRoundTripsEveryMeasurementField() throws {
    let performance = PosterFramePerformanceSnapshot(
      metadataMilliseconds: 1,
      seekAndDecodeMilliseconds: 2,
      imageConversionMilliseconds: 3,
      analysisAndRankingMilliseconds: 4,
      resultImageConversionMilliseconds: 5,
      subtitleAnalysisMilliseconds: 6,
      faceAnalysisMilliseconds: 7,
      aestheticAnalysisMilliseconds: 8,
      decodedFrameCount: 10,
      analyzedFrameCount: 11,
      subtitleAnalyzedFrameCount: 12,
      subtitleAccurateFallbackCount: 13,
      faceAnalyzedFrameCount: 14,
      aestheticAnalyzedFrameCount: 15,
      peakConcurrentDecodes: 4
    )
    let worker = WorkerMeasurement(
      endToEndMilliseconds: 20,
      selectedTimeSeconds: 9.5,
      score: 0.6,
      adjustedScore: 0.7,
      subtitlePenalty: 0.01,
      faceCompositionBonus: 0.02,
      aestheticScore: 0.8,
      isUtilityFrame: false,
      aestheticAdjustment: 0.1,
      memory: SelectionMemoryMeasurement(
        startingResidentBytes: 100,
        sampledPeakResidentBytes: 200,
        endingResidentBytes: 150,
        peakResidentIncreaseBytes: 100
      ),
      performance: performance
    )
    let report = BenchmarkReport(
      schemaVersion: 7,
      label: "schema-test",
      generatedAt: "2026-08-27T00:00:00Z",
      system: BenchmarkSystem(
        chip: "test",
        logicalCoreCount: 4,
        memoryBytes: 1_024,
        operatingSystem: "macOS",
        architecture: "arm64"
      ),
      fixture: BenchmarkFixtureDescription(
        identifier: "fixture",
        codec: "avc1",
        width: 1_280,
        height: 720,
        framesPerSecond: 24,
        durationSeconds: 30,
        generated: true
      ),
      configuration: BenchmarkConfiguration(
        profile: "animation",
        candidateCount: 24,
        searchRange: [0.08, 0.90],
        excludedRanges: [[0.46, 0.54]],
        outputWidth: 1_280,
        outputHeight: 720,
        exactTimeTolerance: true,
        avoidsSubtitles: true,
        subtitleCandidateCount: 5,
        subtitleMaximumPenalty: 0.08,
        prefersFaces: true,
        faceCandidateCount: 8,
        faceMaximumBonus: 0.04,
        prefersAesthetics: true,
        aestheticCandidateCount: 24,
        aestheticMaximumAdjustment: 1,
        residentMemorySamplingIntervalMilliseconds: 2
      ),
      measurements: [
        LaneMeasurement(
          decoderLaneCount: 4,
          processColdRuns: [worker],
          processWarmRuns: [worker],
          processColdMedianMilliseconds: 20,
          processWarmMedianMilliseconds: 20,
          processColdMedianPeakResidentBytes: 200,
          processWarmMedianPeakResidentBytes: 200,
          processColdMedianPeakResidentIncreaseBytes: 100,
          processWarmMedianPeakResidentIncreaseBytes: 100
        )
      ],
      notes: ["test"]
    )

    let decoded = try JSONDecoder().decode(
      BenchmarkReport.self,
      from: JSONEncoder().encode(report)
    )

    XCTAssertEqual(decoded.schemaVersion, 7)
    XCTAssertEqual(decoded.configuration.candidateCount, 24)
    XCTAssertEqual(decoded.measurements.first?.decoderLaneCount, 4)
    XCTAssertEqual(
      decoded.measurements.first?.processWarmRuns.first?.performance,
      performance
    )
    XCTAssertEqual(
      decoded.measurements.first?.processWarmRuns.first?.memory
        .peakResidentIncreaseBytes,
      100
    )
  }
}
