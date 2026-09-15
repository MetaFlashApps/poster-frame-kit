import Foundation
import XCTest

@testable import PosterFrameKitSubtitleBenchmark

final class SubtitleBenchmarkTests: XCTestCase {
  func testCheckedInManifestDefinesPairedRealMaterialCases() throws {
    let manifest = try SubtitleBenchmarkManifest.load(
      from: repositoryRoot.appending(
        path: "Benchmarks/Fixtures/subtitle-calibration.json"
      )
    )

    XCTAssertEqual(manifest.schemaVersion, 1)
    XCTAssertEqual(manifest.sourceFixtureID, "tears-of-steel")
    XCTAssertEqual(manifest.subtitleSources.map(\.language), ["en", "de"])
    XCTAssertEqual(manifest.variants.count, 4)
    XCTAssertEqual(manifest.variants.count(where: { $0.style == .clean }), 1)
    XCTAssertEqual(manifest.samples.count, 13)
    XCTAssertEqual(
      manifest.samples.count(where: \.expectsSubtitleCue),
      10
    )
  }

  func testSRTParserHandlesLineEndingsAndMultipleLines() throws {
    let cues = try SRTParser.parse(
      string: """
        1\r
        00:00:01,250 --> 00:00:03,500\r
        First line\r
        Second line\r
        \r
        2\r
        00:01:02,000 --> 00:01:03,000\r
        Later\r
        """
    )

    XCTAssertEqual(cues.count, 2)
    XCTAssertEqual(cues[0].startSeconds, 1.25)
    XCTAssertEqual(cues[0].endSeconds, 3.5)
    XCTAssertEqual(cues[0].lines, ["First line", "Second line"])
    XCTAssertEqual(cues[1].startSeconds, 62)
    XCTAssertEqual(SRTParser.cue(at: 3.499, in: cues), cues[0])
    XCTAssertNil(SRTParser.cue(at: 3.5, in: cues))
  }

  func testSRTParserRejectsInvalidTimestamp() {
    XCTAssertThrowsError(
      try SRTParser.parse(
        string: "1\n00:61:00,000 --> 00:62:00,000\nBroken"
      )
    ) { error in
      XCTAssertEqual(
        error as? SubtitleBenchmarkError,
        .invalidSubtitle("Invalid SRT timestamp: 00:61:00,000")
      )
    }
  }

  func testArgumentsUseIgnoredDefaultsAndParseOverrides() throws {
    let defaults = try SubtitleBenchmarkArguments(
      arguments: ["benchmark"],
      repositoryRoot: repositoryRoot
    )
    XCTAssertTrue(defaults.writesImages)
    XCTAssertTrue(defaults.reportURL.path.hasSuffix(".subtitle-results/report.json"))

    let overridden = try SubtitleBenchmarkArguments(
      arguments: [
        "benchmark",
        "--manifest", "custom.json",
        "--report", "result.json",
        "--output-directory", "images",
        "--no-images",
      ],
      repositoryRoot: repositoryRoot
    )
    XCTAssertFalse(overridden.writesImages)
    XCTAssertEqual(overridden.manifestURL.lastPathComponent, "custom.json")
    XCTAssertEqual(overridden.reportURL.lastPathComponent, "result.json")
    XCTAssertEqual(overridden.outputDirectory.lastPathComponent, "images")
  }

  func testArgumentsRejectUnknownOption() {
    XCTAssertThrowsError(
      try SubtitleBenchmarkArguments(
        arguments: ["benchmark", "--mystery"],
        repositoryRoot: repositoryRoot
      )
    ) { error in
      XCTAssertEqual(
        error as? SubtitleBenchmarkError,
        .invalidArguments("Unknown argument: --mystery")
      )
    }
  }

  func testCheckedInReportsLockMeasuredImprovement() throws {
    let before = try report(named: "m1-pro-macos-15.7.4-subtitle-real-material-before")
    let after = try report(named: "m1-pro-macos-15.7.4-subtitle-real-material-after")

    XCTAssertEqual(before.schemaVersion, 1)
    XCTAssertEqual(before.benchmarkIdentifier, after.benchmarkIdentifier)
    XCTAssertEqual(before.summary.sampleCount, 52)
    XCTAssertEqual(before.summary.evaluatedSampleCount, 48)
    XCTAssertEqual(before.summary.ambiguousCount, 4)
    XCTAssertEqual(before.summary.falseNegativeCount, 4)
    XCTAssertEqual(before.summary.falsePositiveCount, 0)
    XCTAssertEqual(before.summary.recall ?? 0, 15.0 / 17.0, accuracy: 0.000_001)

    XCTAssertEqual(after.summary.sampleCount, 52)
    XCTAssertEqual(after.summary.evaluatedSampleCount, 48)
    XCTAssertEqual(after.summary.ambiguousCount, 4)
    XCTAssertEqual(after.summary.falseNegativeCount, 0)
    XCTAssertEqual(after.summary.falsePositiveCount, 0)
    XCTAssertEqual(after.summary.recall, 1)
    XCTAssertEqual(after.summary.specificity, 1)
    XCTAssertEqual(
      after.summary.accurateFallbackCount - before.summary.accurateFallbackCount,
      4
    )
  }

  private func report(named name: String) throws -> SubtitleBenchmarkReport {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(
      SubtitleBenchmarkReport.self,
      from: Data(
        contentsOf: repositoryRoot.appending(
          path: "Benchmarks/Reports/\(name).json"
        )
      )
    )
  }

  private var repositoryRoot: URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
