@preconcurrency import AVFoundation
import Foundation
import XCTest

@testable import PosterFrameKitBenchmarkSupport
@testable import PosterFrameKitQualityBenchmark

final class QualityFixtureManifestTests: XCTestCase {
  func testCheckedInManifestMatchesEveryGeneratedDefinition() throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())
    let generated = manifest.fixtures.filter { $0.kind == .generated }

    XCTAssertEqual(manifest.schemaVersion, 2)
    XCTAssertEqual(generated.count, GeneratedFixtureVariant.allCases.count)
    XCTAssertEqual(
      Set(try generated.map { try $0.generatedVariant() }),
      Set(GeneratedFixtureVariant.allCases)
    )
    XCTAssertTrue(
      generated.allSatisfy {
        $0.expectations.reviewStatus == "pending-human-review"
          && $0.acceptableRanges.isEmpty
      }
    )
  }

  func testManifestRejectsGeneratorMetadataDrift() throws {
    let data = try Data(contentsOf: manifestURL())
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    var fixtures = try XCTUnwrap(object["fixtures"] as? [[String: Any]])
    let index = try XCTUnwrap(
      fixtures.firstIndex { $0["kind"] as? String == "generated" }
    )
    var fixture = fixtures[index]
    var generator = try XCTUnwrap(fixture["generator"] as? [String: Any])
    generator["width"] = 123
    fixture["generator"] = generator
    fixtures[index] = fixture
    object["fixtures"] = fixtures

    let directory = temporaryDirectory()
    let url = directory.appending(path: "manifest.json")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try JSONSerialization.data(withJSONObject: object).write(to: url)

    XCTAssertThrowsError(try QualityFixtureManifest.load(from: url)) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Fixture generated-patterns generator metadata does not match standard"
      )
    }
  }

  func testManifestRejectsRetiredProfileNames() throws {
    let data = try Data(contentsOf: manifestURL())
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    var fixtures = try XCTUnwrap(object["fixtures"] as? [[String: Any]])
    var fixture = try XCTUnwrap(fixtures.first)
    var expectations = try XCTUnwrap(
      fixture["expectations"] as? [String: Any]
    )
    expectations["profile"] = "liveAction"
    fixture["expectations"] = expectations
    fixtures[0] = fixture
    object["fixtures"] = fixtures

    let directory = temporaryDirectory()
    let url = directory.appending(path: "manifest.json")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try JSONSerialization.data(withJSONObject: object).write(to: url)

    XCTAssertThrowsError(try QualityFixtureManifest.load(from: url)) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Fixture morevna-demo has an unsupported profile"
      )
    }
  }

  func testResolverGeneratesCatalogFixtureOnDemand() async throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())
    let fixture = try XCTUnwrap(
      manifest.fixtures.first { $0.id == "generated-very-short-single" }
    )
    let directory = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let url = try await QualityFixtureResolver.videoURL(
      for: fixture,
      in: directory
    )
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let tracks = try await asset.loadTracks(withMediaType: .video)

    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    XCTAssertEqual(duration.seconds, 1, accuracy: 0.2)
    XCTAssertEqual(tracks.count, 1)
  }

  func testResolverRejectsMissingDownloadedFixture() async throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())
    let fixture = try XCTUnwrap(
      manifest.fixtures.first { $0.kind == .downloaded && $0.status == "active" }
    )

    do {
      _ = try await QualityFixtureResolver.videoURL(
        for: fixture,
        in: temporaryDirectory()
      )
      XCTFail("Expected missing downloaded fixture to fail")
    } catch let error as QualityBenchmarkError {
      XCTAssertTrue(error.localizedDescription.contains("Missing fixture:"))
    }
  }

  func testDefaultSelectionPreservesReviewedBaseline() throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())

    let fixtures = try manifest.selectedCoreFixtures(
      fixtureIDs: [],
      includePendingReview: false
    )

    XCTAssertEqual(fixtures.count, 5)
    XCTAssertTrue(
      fixtures.allSatisfy { $0.expectations.reviewStatus == "initial-human-review" }
    )
  }

  func testPendingFixturesCanBeSelectedExplicitly() throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())

    let fixtures = try manifest.selectedCoreFixtures(
      fixtureIDs: ["generated-coarse-timestamps"],
      includePendingReview: false
    )

    XCTAssertEqual(fixtures.map(\.id), ["generated-coarse-timestamps"])
  }

  func testIncludingPendingReviewSelectsExpandedCatalog() throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())

    let fixtures = try manifest.selectedCoreFixtures(
      fixtureIDs: [],
      includePendingReview: true
    )

    XCTAssertEqual(fixtures.count, 10)
  }

  func testUnknownFixtureSelectionIsRejected() throws {
    let manifest = try QualityFixtureManifest.load(from: manifestURL())

    XCTAssertThrowsError(
      try manifest.selectedCoreFixtures(
        fixtureIDs: ["not-a-fixture"],
        includePendingReview: false
      )
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "Unknown active core fixture: not-a-fixture"
      )
    }
  }

  func testArgumentsParseFixtureSelection() throws {
    let arguments = try QualityArguments.parse([
      "--fixture", "generated-patterns",
      "--fixture", "generated-subtitles",
      "--include-pending-review",
    ])

    XCTAssertEqual(
      arguments.fixtureIDs,
      ["generated-patterns", "generated-subtitles"]
    )
    XCTAssertTrue(arguments.includePendingReview)
  }

  func testArgumentsParseGalleryDirectory() throws {
    let arguments = try QualityArguments.parse([
      "--gallery-directory", "docs/assets/results-gallery"
    ])

    XCTAssertEqual(
      arguments.galleryDirectory?.path,
      URL(fileURLWithPath: "docs/assets/results-gallery").path
    )
  }

  func testArgumentsParseDeterministicPosterFramePolicy() throws {
    let defaultArguments = try QualityArguments.parse([])
    let deterministicArguments = try QualityArguments.parse([
      "--deterministic-posterframe"
    ])

    XCTAssertEqual(defaultArguments.posterFramePolicy, .visionFirst)
    XCTAssertEqual(deterministicArguments.posterFramePolicy, .deterministic)
  }

  func testArgumentsParseFaceCalibration() throws {
    let arguments = try QualityArguments.parse([
      "--deterministic-posterframe",
      "--calibrate-faces",
    ])

    XCTAssertTrue(arguments.calibratesFaces)
    XCTAssertEqual(arguments.posterFramePolicy, .deterministic)
  }

  func testArgumentsParseAestheticCandidateCalibration() throws {
    let arguments = try QualityArguments.parse([
      "--aesthetic-candidates", "12"
    ])

    XCTAssertEqual(arguments.aestheticCandidateCount, 12)
    XCTAssertEqual(arguments.effectiveAestheticCandidateCount, 12)
    XCTAssertEqual(arguments.posterFramePolicy, .visionFirst)
  }

  func testArgumentsRejectInvalidAestheticCandidateCalibration() {
    XCTAssertThrowsError(
      try QualityArguments.parse(["--aesthetic-candidates", "0"])
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "--aesthetic-candidates requires a positive integer"
      )
    }
    XCTAssertThrowsError(
      try QualityArguments.parse([
        "--deterministic-posterframe",
        "--aesthetic-candidates", "12",
      ])
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "--aesthetic-candidates requires Vision-first PosterFrameKit"
      )
    }
    XCTAssertThrowsError(
      try QualityArguments.parse([
        "--candidates", "8",
        "--aesthetic-candidates", "12",
      ])
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "--aesthetic-candidates must not exceed --candidates"
      )
    }
  }

  func testFaceCalibrationRequiresDeterministicCapture() {
    XCTAssertThrowsError(
      try QualityArguments.parse(["--calibrate-faces"])
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "--calibrate-faces requires --deterministic-posterframe"
      )
    }
  }

  func testArgumentsParseEveryBuiltInProfileOverride() throws {
    for profile in QualityProfileOverride.allCases {
      let arguments = try QualityArguments.parse([
        "--profile", profile.rawValue,
      ])

      XCTAssertEqual(arguments.profileOverride?.rawValue, profile.rawValue)
    }
  }

  func testArgumentsRejectInvalidProfileOverride() {
    XCTAssertThrowsError(
      try QualityArguments.parse(["--profile", "custom"])
    ) { error in
      XCTAssertEqual(
        error.localizedDescription,
        "--profile requires general or animation"
      )
    }
  }

  private func manifestURL() -> URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "Benchmarks/Fixtures/manifest.json")
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
      path: "PosterFrameKitQualityBenchmark-\(UUID().uuidString)"
    )
  }
}
