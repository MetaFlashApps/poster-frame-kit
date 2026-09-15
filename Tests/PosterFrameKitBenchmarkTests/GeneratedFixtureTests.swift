@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import XCTest

@testable import PosterFrameKit
@testable import PosterFrameKitBenchmarkSupport

final class GeneratedFixtureTests: XCTestCase {
  func testDefinitionsAreVersionedAndHaveUniqueIdentifiers() {
    let definitions = GeneratedFixtureVariant.allCases.map(\.definition)

    XCTAssertEqual(
      Set(definitions.map(\.identifier)).count,
      definitions.count
    )
    for definition in definitions {
      XCTAssertGreaterThan(definition.version, 0)
      XCTAssertGreaterThan(definition.width, 0)
      XCTAssertGreaterThan(definition.height, 0)
      XCTAssertGreaterThan(definition.framesPerSecond, 0)
      XCTAssertGreaterThan(definition.durationSeconds, 0)
      XCTAssertGreaterThan(definition.maximumKeyFrameInterval, 0)
      XCTAssertEqual(
        definition.frameCount,
        definition.durationSeconds * definition.framesPerSecond
      )
      let textSegments = definition.textSegments.sorted {
        $0.startFrame < $1.startFrame
      }
      for segment in textSegments {
        XCTAssertGreaterThanOrEqual(segment.startFrame, 0)
        XCTAssertGreaterThan(segment.endFrame, segment.startFrame)
        XCTAssertLessThanOrEqual(segment.endFrame, definition.frameCount)
      }
      for (earlier, later) in zip(textSegments, textSegments.dropFirst()) {
        XCTAssertLessThanOrEqual(earlier.endFrame, later.startFrame)
      }
    }
  }

  func testEveryFixtureCanBeGeneratedWithDeclaredMetadata() async throws {
    let directory = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    for variant in GeneratedFixtureVariant.allCases {
      let definition = variant.definition
      let url = directory.appending(path: "\(variant.rawValue).mp4")

      try await GeneratedFixture.makeIfNeeded(at: url, variant: variant)

      let asset = AVURLAsset(url: url)
      let duration = try await asset.load(.duration)
      let tracks = try await asset.loadTracks(withMediaType: .video)
      let track = try XCTUnwrap(tracks.first)
      let size = try await track.load(.naturalSize)
      let frameRate = try await track.load(.nominalFrameRate)
      let fileSize = try XCTUnwrap(
        try FileManager.default.attributesOfItem(atPath: url.path)[.size]
          as? NSNumber
      ).uint64Value

      XCTAssertGreaterThan(fileSize, 0, variant.rawValue)
      XCTAssertEqual(
        duration.seconds,
        Double(definition.durationSeconds),
        accuracy: 0.2,
        variant.rawValue
      )
      XCTAssertEqual(Int(abs(size.width)), definition.width, variant.rawValue)
      XCTAssertEqual(Int(abs(size.height)), definition.height, variant.rawValue)
      XCTAssertEqual(
        Double(frameRate),
        Double(definition.framesPerSecond),
        accuracy: 0.1,
        variant.rawValue
      )
    }
  }

  func testExistingUsableFixtureIsReused() async throws {
    let directory = temporaryDirectory()
    let url = directory.appending(path: "fixture.mp4")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    try await GeneratedFixture.makeIfNeeded(at: url, variant: .standard)
    let initialAttributes = try FileManager.default.attributesOfItem(
      atPath: url.path
    )
    let initialSize = try XCTUnwrap(initialAttributes[.size] as? NSNumber)
      .uint64Value
    let initialModificationDate = try XCTUnwrap(
      initialAttributes[.modificationDate] as? Date
    )

    try await GeneratedFixture.makeIfNeeded(at: url, variant: .standard)

    let reusedAttributes = try FileManager.default.attributesOfItem(
      atPath: url.path
    )
    XCTAssertEqual(
      try XCTUnwrap(reusedAttributes[.size] as? NSNumber).uint64Value,
      initialSize
    )
    XCTAssertEqual(
      try XCTUnwrap(reusedAttributes[.modificationDate] as? Date),
      initialModificationDate
    )
  }

  func testGenerationObservesCancellation() async throws {
    let directory = temporaryDirectory()
    let url = directory.appending(path: "cancelled.mp4")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let task = Task {
      try await GeneratedFixture.makeIfNeeded(at: url, variant: .standard)
    }
    task.cancel()

    do {
      try await task.value
      XCTFail("Expected fixture generation to observe cancellation")
    } catch is CancellationError {
      // Expected.
    }
  }

  func testVeryShortAndCoarseFixturesCompleteSelection() async throws {
    let directory = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    for variant in [
      GeneratedFixtureVariant.veryShortSingleScene,
      .veryShortMultiScene,
      .coarseTimestamps,
    ] {
      let definition = variant.definition
      let url = directory.appending(path: "\(variant.rawValue).mp4")
      try await GeneratedFixture.makeIfNeeded(at: url, variant: variant)

      let result = try await PosterFrameKit.bestFrame(
        in: url,
        options: PosterFrameOptions(
          maximumFramesExamined: 40,
          outputSize: CGSize(width: 160, height: 90)
        )
      )

      XCTAssertGreaterThanOrEqual(result.time.seconds, 0, variant.rawValue)
      XCTAssertLessThan(
        result.time.seconds,
        Double(definition.durationSeconds),
        variant.rawValue
      )
      XCTAssertGreaterThan(result.image.width, 0, variant.rawValue)
      XCTAssertGreaterThan(result.image.height, 0, variant.rawValue)
      if variant == .coarseTimestamps {
        XCTAssertEqual(
          result.time.seconds * Double(definition.framesPerSecond),
          round(result.time.seconds * Double(definition.framesPerSecond)),
          accuracy: 0.001
        )
      }
    }
  }

  func testSubtitleCalibrationTargetsLowerTextButPreservesSceneSign() async throws {
    let directory = temporaryDirectory()
    let url = directory.appending(path: "subtitle-calibration.mp4")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try await GeneratedFixture.makeIfNeeded(at: url, variant: .subtitles)
    let source = AVFoundationFrameSource(url: url)
    let analyzer = VisionSubtitleAnalyzer()

    let clean = try await analyzeSubtitle(
      at: 17.5,
      source: source,
      analyzer: analyzer
    )
    let dialogue = try await analyzeSubtitle(
      at: 9.5,
      source: source,
      analyzer: analyzer
    )
    let credits = try await analyzeSubtitle(
      at: 14.5,
      source: source,
      analyzer: analyzer
    )
    let sceneSign = try await analyzeSubtitle(
      at: 19.5,
      source: source,
      analyzer: analyzer
    )

    XCTAssertEqual(clean.likelihood, 0)
    XCTAssertGreaterThan(dialogue.likelihood, 0)
    XCTAssertGreaterThan(credits.likelihood, 0)
    XCTAssertEqual(sceneSign.likelihood, 0)
  }

  private func analyzeSubtitle(
    at seconds: Double,
    source: AVFoundationFrameSource,
    analyzer: VisionSubtitleAnalyzer
  ) async throws -> SubtitleAnalysis {
    let sample = try await source.frame(
      at: CMTime(seconds: seconds, preferredTimescale: 600),
      maximumSize: CGSize(width: 1_280, height: 720)
    )
    return try await analyzer.analyze(sample.pixelBuffer)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(
      path: "PosterFrameKitBenchmark-\(UUID().uuidString)"
    )
  }
}
