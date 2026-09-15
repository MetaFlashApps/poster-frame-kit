import Foundation
import ImageIO
import XCTest

@testable import PosterFrameKitQualityBenchmark

final class QualityGalleryTests: XCTestCase {
  func testCheckedInReportContainsPublishedMidpointEvidence() throws {
    let reportURL = repositoryRoot.appending(
      path: "Benchmarks/Reports/m1-pro-macos-15.7.4-quality.json"
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(
      QualityReport.self,
      from: Data(contentsOf: reportURL)
    )

    XCTAssertEqual(report.schemaVersion, 3)
    XCTAssertEqual(report.candidateCount, 24)
    XCTAssertEqual(report.fixtures.count, 5)
    for fixture in report.fixtures {
      XCTAssertEqual(
        fixture.midpoint.imagePath,
        "\(fixture.id)/midpoint.png"
      )
      XCTAssertTrue(fixture.midpoint.timeSeconds.isFinite)
      XCTAssertGreaterThanOrEqual(fixture.midpoint.timeSeconds, 0)
    }
  }

  func testCheckedInFaceCalibrationCoversEveryCoreCandidate() throws {
    let reportURL = repositoryRoot.appending(
      path: "Benchmarks/Reports/m1-pro-macos-15.7.4-face-calibration.json"
    )
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try decoder.decode(
      QualityReport.self,
      from: Data(contentsOf: reportURL)
    )

    XCTAssertEqual(report.schemaVersion, 4)
    XCTAssertEqual(report.candidateCount, 24)
    XCTAssertEqual(report.fixtures.count, 5)
    XCTAssertEqual(
      report.fixtures.reduce(0) {
        $0 + ($1.faceCalibration?.candidates.count ?? 0)
      },
      110
    )
    for fixture in report.fixtures {
      let calibration = try XCTUnwrap(fixture.faceCalibration)
      XCTAssertEqual(calibration.candidates.count, 22)
      XCTAssertTrue(calibration.detectionsStable)
    }
  }

  func testCheckedInAestheticCapReportsCoverEveryCoreFixture() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    for candidateCount in [8, 12, 16, 24] {
      let reportURL = repositoryRoot.appending(
        path:
          "Benchmarks/Reports/m1-pro-macos-15.7.4-aesthetic-cap-quality-\(candidateCount).json"
      )
      let report = try decoder.decode(
        QualityReport.self,
        from: Data(contentsOf: reportURL)
      )

      XCTAssertEqual(report.schemaVersion, 5)
      XCTAssertEqual(report.candidateCount, 24)
      XCTAssertEqual(report.aestheticCandidateCount, candidateCount)
      XCTAssertEqual(report.fixtures.count, 5)
      XCTAssertTrue(
        report.fixtures.allSatisfy {
          $0.decodedCandidateCount == 22
            && $0.posterFrameKit.acceptable == true
        }
      )
    }
  }

  func testGeneratedFixtureProducesMidpointAndGalleryJPEGs() async throws {
    guard #available(macOS 15.0, *) else {
      throw XCTSkip("Vision image aesthetics is unavailable.")
    }

    let manifestURL = repositoryRoot.appending(
      path: "Benchmarks/Fixtures/manifest.json"
    )
    let manifest = try QualityFixtureManifest.load(from: manifestURL)
    let fixture = try XCTUnwrap(
      manifest.fixtures.first { $0.id == "generated-very-short-single" }
    )
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "PosterFrameKitQualityGallery-\(UUID().uuidString)"
    )
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    let videoURL = try await QualityFixtureResolver.videoURL(
      for: fixture,
      in: directory.appending(path: "fixtures")
    )
    let outputDirectory = directory.appending(path: "results")
    let galleryDirectory = directory.appending(path: "gallery")

    let result = try await QualityComparisonRunner.run(
      fixture: fixture,
      videoURL: videoURL,
      candidateCount: 2,
      outputDirectory: outputDirectory,
      galleryDirectory: galleryDirectory,
      posterFramePolicy: .deterministic
    )

    XCTAssertEqual(result.midpoint.timeSeconds, 0.5, accuracy: 0.1)
    XCTAssertEqual(result.posterFrameKit.faceCompositionBonus, 0)
    XCTAssertNil(result.posterFrameKit.visionScore)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: outputDirectory.appending(
          path: "generated-very-short-single/midpoint.png"
        ).path
      )
    )
    for fileName in ["midpoint.jpg", "posterframekit.jpg"] {
      let url = galleryDirectory.appending(
        path: "generated-very-short-single/\(fileName)"
      )
      let source = try XCTUnwrap(
        CGImageSourceCreateWithURL(url as CFURL, nil)
      )
      XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.jpeg")
      XCTAssertGreaterThan(CGImageSourceGetCount(source), 0)
    }
  }

  func testGeneratedFixtureProducesFaceCalibrationReportAndContactSheet() async throws {
    guard #available(macOS 15.0, *) else {
      throw XCTSkip("Vision image aesthetics is unavailable.")
    }

    let manifestURL = repositoryRoot.appending(
      path: "Benchmarks/Fixtures/manifest.json"
    )
    let manifest = try QualityFixtureManifest.load(from: manifestURL)
    let fixture = try XCTUnwrap(
      manifest.fixtures.first { $0.id == "generated-very-short-single" }
    )
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "PosterFrameKitFaceCalibration-\(UUID().uuidString)"
    )
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    let videoURL = try await QualityFixtureResolver.videoURL(
      for: fixture,
      in: directory.appending(path: "fixtures")
    )
    let outputDirectory = directory.appending(path: "results")

    let result = try await QualityComparisonRunner.run(
      fixture: fixture,
      videoURL: videoURL,
      candidateCount: 2,
      outputDirectory: outputDirectory,
      galleryDirectory: nil,
      posterFramePolicy: .deterministic,
      includesFaceCalibration: true
    )

    let calibration = try XCTUnwrap(result.faceCalibration)
    XCTAssertEqual(calibration.candidates.count, 2)
    XCTAssertEqual(calibration.detectedCandidateCount, 0)
    XCTAssertEqual(calibration.scoredCandidateCount, 0)
    XCTAssertEqual(calibration.totalFaceCount, 0)
    XCTAssertTrue(calibration.detectionsStable)
    XCTAssertGreaterThan(calibration.firstPassMilliseconds, 0)
    XCTAssertGreaterThan(calibration.warmPassMilliseconds, 0)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: outputDirectory.appending(
          path: calibration.contactSheetPath
        ).path
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
