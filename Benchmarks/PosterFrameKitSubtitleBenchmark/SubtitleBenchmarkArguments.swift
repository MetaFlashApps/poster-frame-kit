import Foundation

struct SubtitleBenchmarkArguments: Equatable {
  var manifestURL: URL
  var reportURL: URL
  var outputDirectory: URL
  var writesImages = true

  init(arguments: [String], repositoryRoot: URL) throws {
    manifestURL = repositoryRoot.appending(
      path: "Benchmarks/Fixtures/subtitle-calibration.json"
    )
    reportURL = repositoryRoot.appending(
      path: "Benchmarks/.subtitle-results/report.json"
    )
    outputDirectory = repositoryRoot.appending(
      path: "Benchmarks/.subtitle-results/images"
    )

    var index = 1
    while index < arguments.count {
      switch arguments[index] {
      case "--manifest":
        index += 1
        manifestURL = URL(
          filePath: try Self.value(arguments, at: index),
          relativeTo: repositoryRoot
        ).standardizedFileURL
      case "--report":
        index += 1
        reportURL = URL(
          filePath: try Self.value(arguments, at: index),
          relativeTo: repositoryRoot
        ).standardizedFileURL
      case "--output-directory":
        index += 1
        outputDirectory = URL(
          filePath: try Self.value(arguments, at: index),
          relativeTo: repositoryRoot
        ).standardizedFileURL
      case "--no-images":
        writesImages = false
      default:
        throw SubtitleBenchmarkError.invalidArguments(
          "Unknown argument: \(arguments[index])"
        )
      }
      index += 1
    }
  }

  private static func value(_ arguments: [String], at index: Int) throws -> String {
    guard arguments.indices.contains(index) else {
      throw SubtitleBenchmarkError.invalidArguments("Missing argument value.")
    }
    return arguments[index]
  }
}
