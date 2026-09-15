import Foundation
import PosterFrameKitBenchmarkSupport

struct BenchmarkArguments {
  var isWorker = false
  var fixtureURL: URL?
  var outputURL: URL?
  var label = "local"
  var laneCounts = [1]
  var candidateCount = 40
  var excludesMidroll = false
  var generatedFixtureVariant = GeneratedFixtureVariant.standard
  var avoidsSubtitles = false
  var subtitleCandidateCount = 8
  var subtitleMaximumPenalty = 0.08
  var prefersFaces = false
  var faceCandidateCount = 8
  var faceMaximumBonus = 0.04
  var prefersAesthetics = false
  var aestheticCandidateCount = 24
  var aestheticMaximumAdjustment = 1.0
  var coldRuns = 3
  var warmRuns = 3
  var warmupCount = 0

  init(_ arguments: [String]) throws {
    var index = 1
    while index < arguments.count {
      switch arguments[index] {
      case "--worker":
        isWorker = true
      case "--fixture":
        index += 1
        fixtureURL = URL(fileURLWithPath: try Self.value(arguments, at: index))
      case "--output":
        index += 1
        outputURL = URL(fileURLWithPath: try Self.value(arguments, at: index))
      case "--label":
        index += 1
        label = try Self.value(arguments, at: index)
      case "--lanes":
        index += 1
        let parsedLaneCounts = try Self.value(arguments, at: index)
          .split(separator: ",")
          .map {
            guard let value = Int($0), value > 0 else {
              throw BenchmarkError.invalidArguments(
                "Lane counts must be positive integers.")
            }
            return value
          }
        guard !parsedLaneCounts.isEmpty else {
          throw BenchmarkError.invalidArguments(
            "At least one lane count is required."
          )
        }
        laneCounts = parsedLaneCounts
      case "--candidates":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)),
          value > 0
        else {
          throw BenchmarkError.invalidArguments(
            "Candidate count must be greater than zero."
          )
        }
        candidateCount = value
      case "--exclude-midroll":
        excludesMidroll = true
      case "--generated-fixture":
        index += 1
        let value = try Self.value(arguments, at: index)
        guard let variant = GeneratedFixtureVariant(rawValue: value) else {
          throw BenchmarkError.invalidArguments(
            "Unknown generated fixture variant: \(value)."
          )
        }
        generatedFixtureVariant = variant
      case "--avoid-subtitles":
        avoidsSubtitles = true
      case "--subtitle-candidates":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)),
          value > 0
        else {
          throw BenchmarkError.invalidArguments(
            "Subtitle candidate count must be greater than zero."
          )
        }
        subtitleCandidateCount = value
      case "--subtitle-maximum-penalty":
        index += 1
        guard let value = Double(try Self.value(arguments, at: index)),
          value.isFinite,
          (0...1).contains(value)
        else {
          throw BenchmarkError.invalidArguments(
            "Subtitle maximum penalty must be between zero and one."
          )
        }
        subtitleMaximumPenalty = value
      case "--prefer-faces":
        prefersFaces = true
      case "--face-candidates":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)),
          value > 0
        else {
          throw BenchmarkError.invalidArguments(
            "Face candidate count must be greater than zero."
          )
        }
        faceCandidateCount = value
      case "--face-maximum-bonus":
        index += 1
        guard let value = Double(try Self.value(arguments, at: index)),
          value.isFinite,
          (0...1).contains(value)
        else {
          throw BenchmarkError.invalidArguments(
            "Face maximum bonus must be between zero and one."
          )
        }
        faceMaximumBonus = value
      case "--prefer-aesthetics":
        prefersAesthetics = true
      case "--aesthetic-candidates":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)),
          value > 0
        else {
          throw BenchmarkError.invalidArguments(
            "Aesthetic candidate count must be greater than zero."
          )
        }
        aestheticCandidateCount = value
      case "--aesthetic-maximum-adjustment":
        index += 1
        guard let value = Double(try Self.value(arguments, at: index)),
          value.isFinite,
          (0...1).contains(value)
        else {
          throw BenchmarkError.invalidArguments(
            "Aesthetic maximum adjustment must be between zero and one."
          )
        }
        aestheticMaximumAdjustment = value
      case "--warm-runs":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)), value > 0 else {
          throw BenchmarkError.invalidArguments("Warm runs must be greater than zero.")
        }
        warmRuns = value
      case "--cold-runs":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)), value > 0 else {
          throw BenchmarkError.invalidArguments("Cold runs must be greater than zero.")
        }
        coldRuns = value
      case "--warmup-count":
        index += 1
        guard let value = Int(try Self.value(arguments, at: index)), value >= 0 else {
          throw BenchmarkError.invalidArguments("Warmup count must not be negative.")
        }
        warmupCount = value
      default:
        throw BenchmarkError.invalidArguments("Unknown argument: \(arguments[index])")
      }
      index += 1
    }
  }

  private static func value(_ arguments: [String], at index: Int) throws -> String {
    guard arguments.indices.contains(index) else {
      throw BenchmarkError.invalidArguments("Missing argument value.")
    }
    return arguments[index]
  }
}

enum BenchmarkError: LocalizedError {
  case invalidArguments(String)
  case fixtureCreationFailed(String)
  case workerFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidArguments(let message),
      .fixtureCreationFailed(let message),
      .workerFailed(let message):
      message
    }
  }
}
