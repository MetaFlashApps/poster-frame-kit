import PosterFrameKit
import XCTest

@testable import PosterFrameKitBenchmark

final class BenchmarkArgumentsTests: XCTestCase {
  func testDefaultsMatchPublicSubtitleConfiguration() throws {
    let arguments = try BenchmarkArguments(["PosterFrameKitBenchmark"])

    XCTAssertEqual(
      arguments.subtitleCandidateCount,
      PosterFrameSubtitleOptions().candidateCount
    )
  }

  func testParsesIndependentBenchmarkControls() throws {
    let arguments = try BenchmarkArguments([
      "PosterFrameKitBenchmark",
      "--label", "candidate-study",
      "--lanes", "1,2,4",
      "--candidates", "24",
      "--exclude-midroll",
      "--avoid-subtitles",
      "--subtitle-candidates", "5",
      "--subtitle-maximum-penalty", "0.08",
      "--prefer-faces",
      "--face-candidates", "8",
      "--face-maximum-bonus", "0.04",
      "--prefer-aesthetics",
      "--aesthetic-candidates", "16",
      "--aesthetic-maximum-adjustment", "1",
      "--cold-runs", "2",
      "--warm-runs", "3",
    ])

    XCTAssertEqual(arguments.label, "candidate-study")
    XCTAssertEqual(arguments.laneCounts, [1, 2, 4])
    XCTAssertEqual(arguments.candidateCount, 24)
    XCTAssertTrue(arguments.excludesMidroll)
    XCTAssertTrue(arguments.avoidsSubtitles)
    XCTAssertTrue(arguments.prefersFaces)
    XCTAssertTrue(arguments.prefersAesthetics)
    XCTAssertEqual(arguments.aestheticCandidateCount, 16)
    XCTAssertEqual(arguments.coldRuns, 2)
    XCTAssertEqual(arguments.warmRuns, 3)
  }

  func testRejectsInvalidPositiveCounts() {
    XCTAssertThrowsError(
      try BenchmarkArguments([
        "PosterFrameKitBenchmark",
        "--candidates", "0",
      ])
    )
    XCTAssertThrowsError(
      try BenchmarkArguments([
        "PosterFrameKitBenchmark",
        "--lanes", "1,0",
      ])
    )
    XCTAssertThrowsError(
      try BenchmarkArguments([
        "PosterFrameKitBenchmark",
        "--lanes", "",
      ])
    )
  }
}
