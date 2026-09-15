import Foundation
import PosterFrameKitBenchmarkSupport

enum QualityFixtureResolver {
  static func videoURL(
    for fixture: QualityFixtureManifest.Fixture,
    in fixtureDirectory: URL
  ) async throws -> URL {
    guard let outputFileName = fixture.outputFileName else {
      throw QualityBenchmarkError.invalidManifest(
        "Active fixture \(fixture.id) has no outputFileName"
      )
    }
    let videoURL = fixtureDirectory.appending(path: outputFileName)
    switch fixture.kind {
    case .generated:
      try await GeneratedFixture.makeIfNeeded(
        at: videoURL,
        variant: try fixture.generatedVariant()
      )
    case .downloaded:
      guard FileManager.default.fileExists(atPath: videoURL.path) else {
        throw QualityBenchmarkError.invalidManifest(
          "Missing fixture: \(videoURL.path). "
            + "Run Scripts/fetch-benchmark-fixtures.py first."
        )
      }
    }
    return videoURL
  }
}
