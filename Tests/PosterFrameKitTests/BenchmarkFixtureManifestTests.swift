import Foundation
import ImageIO
import XCTest

final class BenchmarkFixtureManifestTests: XCTestCase {
  func testManifestHasUniqueLicensedAndGeneratedFixtures() throws {
    let manifest = try loadManifest()

    XCTAssertEqual(manifest.schemaVersion, 2)
    XCTAssertEqual(
      Set(manifest.fixtures.map(\.id)).count,
      manifest.fixtures.count
    )

    let activeFixtures = manifest.fixtures.filter { $0.status == "active" }
    XCTAssertEqual(activeFixtures.count, 10)
    XCTAssertEqual(
      Set(activeFixtures.compactMap(\.outputFileName)).count,
      activeFixtures.count
    )
    XCTAssertEqual(
      activeFixtures.filter { $0.kind == "downloaded" }.count,
      5
    )
    XCTAssertEqual(
      activeFixtures.filter { $0.kind == "generated" }.count,
      5
    )
  }

  func testActiveDownloadedFixturesRemainLicensedAndReviewed() throws {
    let fixtures = try loadManifest().fixtures.filter {
      $0.status == "active" && $0.kind == "downloaded"
    }

    for fixture in fixtures {
      XCTAssertEqual(fixture.tier, "core")
      let source = try XCTUnwrap(fixture.source)
      XCTAssertTrue(source.projectURL.hasPrefix("https://"))
      XCTAssertTrue(source.downloadURL.hasPrefix("https://"))
      XCTAssertFalse(source.license.spdx.isEmpty)
      XCTAssertFalse(source.license.attribution.isEmpty)
      XCTAssertGreaterThan(source.expectedBytes, 0)
      XCTAssertEqual(source.sha256?.count, 64)
      XCTAssertTrue(fixture.transform?.removeAudio == true)
      XCTAssertNil(fixture.generator)
      XCTAssertTrue(fixture.outputFileName?.hasSuffix(".mp4") == true)
      XCTAssertEqual(
        fixture.expectations.reviewStatus,
        "initial-human-review"
      )
      XCTAssertFalse(fixture.expectations.acceptableTimeRanges.isEmpty)
      assertValidRanges(fixture.expectations.acceptableTimeRanges)
    }
  }

  func testGeneratedFixturesHaveVersionedDefinitionsPendingReview() throws {
    let fixtures = try loadManifest().fixtures.filter {
      $0.status == "active" && $0.kind == "generated"
    }

    XCTAssertEqual(
      Set(fixtures.compactMap { $0.generator?.variant }),
      [
        "standard",
        "subtitles",
        "very-short-single-scene",
        "very-short-multi-scene",
        "coarse-timestamps",
      ]
    )
    for fixture in fixtures {
      let generator = try XCTUnwrap(fixture.generator)
      XCTAssertEqual(generator.name, "poster-frame-kit-synthetic-video")
      XCTAssertGreaterThan(generator.version, 0)
      XCTAssertGreaterThan(generator.width, 0)
      XCTAssertGreaterThan(generator.height, 0)
      XCTAssertGreaterThan(generator.framesPerSecond, 0)
      XCTAssertGreaterThan(generator.durationSeconds, 0)
      XCTAssertGreaterThan(generator.maximumKeyFrameInterval, 0)
      XCTAssertNil(fixture.source)
      XCTAssertNil(fixture.transform)
      XCTAssertEqual(
        fixture.expectations.reviewStatus,
        "pending-human-review"
      )
      XCTAssertTrue(fixture.expectations.acceptableTimeRanges.isEmpty)
    }
  }

  func testDeferredFixturesCannotBeFetchedByDefault() throws {
    let deferred = try loadManifest().fixtures.filter { $0.status == "deferred" }

    XCTAssertEqual(Set(deferred.map(\.tier)), ["extended"])
    XCTAssertTrue(deferred.allSatisfy { $0.kind == "downloaded" })
    XCTAssertTrue(deferred.allSatisfy { $0.transform == nil })
    XCTAssertTrue(deferred.allSatisfy { $0.outputFileName == nil })
  }

  func testPublishedResultsGalleryMatchesLicensedCoreFixtures() throws {
    let fixtures = try loadManifest().fixtures.filter {
      $0.status == "active" && $0.kind == "downloaded"
    }
    let galleryDirectory = repositoryRoot.appending(
      path: "docs/assets/results-gallery"
    )
    let galleryDocumentation = try String(
      contentsOf: galleryDirectory.appending(path: "README.md"),
      encoding: .utf8
    )
    let documentedAttributions = galleryDocumentation.replacingOccurrences(
      of: "\\|",
      with: "|"
    )
    var expectedPaths: Set<String> = []

    for fixture in fixtures {
      let attribution = try XCTUnwrap(fixture.source?.license.attribution)
      XCTAssertTrue(documentedAttributions.contains(attribution))

      for fileName in ["midpoint.jpg", "posterframekit.jpg"] {
        let relativePath = "\(fixture.id)/\(fileName)"
        expectedPaths.insert(relativePath)
        let url = galleryDirectory.appending(path: relativePath)
        let source = try XCTUnwrap(
          CGImageSourceCreateWithURL(url as CFURL, nil)
        )
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.jpeg")
        let image = try XCTUnwrap(
          CGImageSourceCreateImageAtIndex(source, 0, nil)
        )
        XCTAssertGreaterThan(image.width, 300)
        XCTAssertGreaterThan(image.height, 200)
      }
    }

    let comparisonPath = "morevna-demo/comparison.jpg"
    expectedPaths.insert(comparisonPath)
    let comparisonSource = try XCTUnwrap(
      CGImageSourceCreateWithURL(
        galleryDirectory.appending(path: comparisonPath) as CFURL,
        nil
      )
    )
    let comparisonImage = try XCTUnwrap(
      CGImageSourceCreateImageAtIndex(comparisonSource, 0, nil)
    )
    XCTAssertEqual(
      CGImageSourceGetType(comparisonSource) as String?,
      "public.jpeg"
    )
    XCTAssertGreaterThan(comparisonImage.width, comparisonImage.height * 3)

    let enumerator = try XCTUnwrap(
      FileManager.default.enumerator(
        at: galleryDirectory,
        includingPropertiesForKeys: nil
      )
    )
    let actualPaths = Set(
      enumerator.compactMap { item -> String? in
        guard let url = item as? URL, url.pathExtension == "jpg" else {
          return nil
        }
        return String(url.path.dropFirst(galleryDirectory.path.count + 1))
      }
    )
    XCTAssertEqual(actualPaths, expectedPaths)
  }

  private func assertValidRanges(
    _ ranges: [[Double]],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    for range in ranges {
      XCTAssertEqual(range.count, 2, file: file, line: line)
      guard range.count == 2 else {
        continue
      }
      XCTAssertGreaterThanOrEqual(range[0], 0, file: file, line: line)
      XCTAssertGreaterThanOrEqual(range[1], range[0], file: file, line: line)
    }
  }

  private func loadManifest() throws -> FixtureManifest {
    let url = repositoryRoot.appending(
      path: "Benchmarks/Fixtures/manifest.json"
    )
    return try JSONDecoder().decode(
      FixtureManifest.self,
      from: Data(contentsOf: url)
    )
  }

  private var repositoryRoot: URL {
    URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}

private struct FixtureManifest: Decodable {
  let schemaVersion: Int
  let fixtures: [Fixture]
}

private struct Fixture: Decodable {
  let id: String
  let kind: String
  let status: String
  let tier: String
  let source: Source?
  let generator: Generator?
  let transform: Transform?
  let outputFileName: String?
  let expectations: Expectations
}

private struct Source: Decodable {
  let projectURL: String
  let downloadURL: String
  let expectedBytes: Int
  let sha256: String?
  let license: License
}

private struct License: Decodable {
  let spdx: String
  let attribution: String
}

private struct Generator: Decodable {
  let name: String
  let version: Int
  let variant: String
  let width: Int
  let height: Int
  let framesPerSecond: Int
  let durationSeconds: Int
  let maximumKeyFrameInterval: Int
}

private struct Transform: Decodable {
  let removeAudio: Bool
}

private struct Expectations: Decodable {
  let reviewStatus: String
  let acceptableTimeRanges: [[Double]]
}
