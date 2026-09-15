import Foundation

struct SubtitleBenchmarkManifest: Decodable, Sendable {
  let schemaVersion: Int
  let identifier: String
  let rendererVersion: Int
  let sourceFixtureID: String
  let sourceVideoPath: String
  let subtitleDirectory: String
  let resultDirectory: String
  let source: Source
  let subtitleSources: [SubtitleSource]
  let variants: [Variant]
  let samples: [Sample]

  struct Source: Codable, Sendable {
    let title: String
    let creator: String
    let projectURL: String
    let license: License
  }

  struct License: Codable, Sendable {
    let spdx: String
    let url: String
    let attribution: String
  }

  struct SubtitleSource: Codable, Sendable {
    let id: String
    let language: String
    let downloadURL: String
    let fileName: String
    let expectedBytes: Int
    let sha256: String
  }

  struct Variant: Codable, Sendable {
    let id: String
    let subtitleSourceID: String?
    let style: SubtitleRenderStyle
  }

  struct Sample: Codable, Sendable {
    let id: String
    let sourceTimeSeconds: Double
    let expectsSubtitleCue: Bool
    let sourceExpectation: SourceExpectation
    let tags: [String]
  }

  static func load(from url: URL) throws -> Self {
    let manifest = try JSONDecoder().decode(
      Self.self,
      from: Data(contentsOf: url)
    )
    try manifest.validate()
    return manifest
  }

  func validate() throws {
    guard schemaVersion == 1 else {
      throw SubtitleBenchmarkError.invalidManifest("schemaVersion must be 1")
    }
    guard rendererVersion == 1 else {
      throw SubtitleBenchmarkError.invalidManifest(
        "rendererVersion must be 1"
      )
    }
    guard !identifier.isEmpty, !sourceFixtureID.isEmpty,
      !sourceVideoPath.isEmpty, !subtitleDirectory.isEmpty,
      !resultDirectory.isEmpty
    else {
      throw SubtitleBenchmarkError.invalidManifest(
        "manifest paths and identifiers must not be empty"
      )
    }
    guard !subtitleSources.isEmpty, !variants.isEmpty, !samples.isEmpty else {
      throw SubtitleBenchmarkError.invalidManifest(
        "subtitleSources, variants, and samples must not be empty"
      )
    }
    guard Set(subtitleSources.map(\.id)).count == subtitleSources.count else {
      throw SubtitleBenchmarkError.invalidManifest(
        "subtitle source ids must be unique"
      )
    }
    guard Set(variants.map(\.id)).count == variants.count else {
      throw SubtitleBenchmarkError.invalidManifest(
        "variant ids must be unique"
      )
    }
    guard Set(samples.map(\.id)).count == samples.count else {
      throw SubtitleBenchmarkError.invalidManifest(
        "sample ids must be unique"
      )
    }
    let sourceIDs = Set(subtitleSources.map(\.id))
    for variant in variants {
      switch variant.style {
      case .clean:
        guard variant.subtitleSourceID == nil else {
          throw SubtitleBenchmarkError.invalidManifest(
            "clean variant cannot reference subtitles"
          )
        }
      case .outline, .boxed:
        guard let id = variant.subtitleSourceID, sourceIDs.contains(id) else {
          throw SubtitleBenchmarkError.invalidManifest(
            "rendered variant must reference a known subtitle source"
          )
        }
      }
    }
    guard variants.count(where: { $0.style == .clean }) == 1 else {
      throw SubtitleBenchmarkError.invalidManifest(
        "exactly one clean variant is required"
      )
    }
    for sample in samples {
      guard sample.sourceTimeSeconds.isFinite,
        sample.sourceTimeSeconds >= 0,
        !sample.tags.isEmpty,
        Set(sample.tags).count == sample.tags.count
      else {
        throw SubtitleBenchmarkError.invalidManifest(
          "sample timestamps and tags must be valid"
        )
      }
    }
  }
}

enum SubtitleRenderStyle: String, Codable, Sendable {
  case clean
  case outline
  case boxed
}

enum SourceExpectation: String, Codable, Sendable {
  case clean
  case unwantedLowerThird = "unwanted-lower-third"
  case ambiguous
}

enum SubtitleBenchmarkError: Error, LocalizedError, Equatable {
  case invalidArguments(String)
  case invalidManifest(String)
  case invalidSubtitle(String)
  case fixtureUnavailable(String)
  case imageCreationFailed

  var errorDescription: String? {
    switch self {
    case .invalidArguments(let message),
      .invalidManifest(let message),
      .invalidSubtitle(let message),
      .fixtureUnavailable(let message):
      message
    case .imageCreationFailed:
      "Cannot create a calibration image."
    }
  }
}
