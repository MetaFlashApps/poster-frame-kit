import Darwin
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import PosterFrameKit

@main
enum PosterFrameKitSubtitleBenchmark {
  static func main() async {
    do {
      try await run()
    } catch {
      FileHandle.standardError.write(
        Data("error: \(error.localizedDescription)\n".utf8)
      )
      exit(EXIT_FAILURE)
    }
  }

  private static func run() async throws {
    let repositoryRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let arguments = try SubtitleBenchmarkArguments(
      arguments: CommandLine.arguments,
      repositoryRoot: repositoryRoot
    )
    let manifest = try SubtitleBenchmarkManifest.load(from: arguments.manifestURL)
    let videoURL = try repositoryURL(
      manifest.sourceVideoPath,
      root: repositoryRoot
    )
    guard FileManager.default.fileExists(atPath: videoURL.path) else {
      throw SubtitleBenchmarkError.fixtureUnavailable(
        "Source video is missing; run Scripts/fetch-subtitle-calibration-fixtures.py"
      )
    }

    let subtitleDirectory = try repositoryURL(
      manifest.subtitleDirectory,
      root: repositoryRoot
    )
    let subtitleSources = Dictionary(
      uniqueKeysWithValues: manifest.subtitleSources.map { ($0.id, $0) }
    )
    var cuesBySourceID: [String: [SubtitleCue]] = [:]
    for source in manifest.subtitleSources {
      let url = subtitleDirectory.appending(path: source.fileName)
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw SubtitleBenchmarkError.fixtureUnavailable(
          "Subtitle input is missing; run Scripts/fetch-subtitle-calibration-fixtures.py"
        )
      }
      cuesBySourceID[source.id] = try SRTParser.parse(
        data: Data(contentsOf: url)
      )
    }

    let frameSource = AVFoundationFrameSource(url: videoURL)
    let renderer = SubtitleFrameRenderer()
    let analyzer = VisionSubtitleAnalyzer()
    if let first = manifest.samples.first {
      let warmup = try await frameSource.frame(
        at: CMTime(seconds: first.sourceTimeSeconds, preferredTimescale: 600),
        maximumSize: CGSize(width: 1_280, height: 720)
      )
      _ = try await analyzer.analyze(warmup.pixelBuffer)
    }

    if arguments.writesImages {
      try FileManager.default.createDirectory(
        at: arguments.outputDirectory,
        withIntermediateDirectories: true
      )
    }
    var results: [SubtitleBenchmarkReport.SampleResult] = []
    for sample in manifest.samples {
      let decoded = try await frameSource.frame(
        at: CMTime(seconds: sample.sourceTimeSeconds, preferredTimescale: 600),
        maximumSize: CGSize(width: 1_280, height: 720)
      )
      let actualTime = decoded.actualTime.seconds
      for variant in manifest.variants {
        let subtitleSource = variant.subtitleSourceID.flatMap {
          subtitleSources[$0]
        }
        let cue = variant.subtitleSourceID.flatMap {
          cuesBySourceID[$0].flatMap { SRTParser.cue(at: actualTime, in: $0) }
        }
        if variant.style != .clean,
          (cue != nil) != sample.expectsSubtitleCue
        {
          throw SubtitleBenchmarkError.invalidManifest(
            "Sample \(sample.id) does not match \(variant.id) subtitle timing"
          )
        }
        let pixelBuffer: CVPixelBuffer
        if let cue {
          pixelBuffer = try renderer.render(
            cue: cue,
            style: variant.style,
            on: decoded.pixelBuffer
          )
        } else {
          pixelBuffer = decoded.pixelBuffer
        }

        let start = ContinuousClock.now
        let analysis = try await analyzer.analyze(pixelBuffer)
        let elapsed = start.duration(to: .now).milliseconds
        let detected = analysis.likelihood > 0
        let expected: Bool?
        switch sample.sourceExpectation {
        case .unwantedLowerThird:
          expected = true
        case .ambiguous:
          expected = nil
        case .clean:
          expected = variant.style == .clean
            ? false
            : sample.expectsSubtitleCue
        }
        var heuristic = SubtitleBandHeuristic()
        let heuristicDiagnostics = try heuristic.diagnostics(pixelBuffer)
        let accurateDiagnosticLikelihood: Double?
        let accurateDiagnosticMilliseconds: Double?
        if expected == true, !detected {
          let diagnosticStart = ContinuousClock.now
          let accurate = try await analyzer.analyzeAccurately(pixelBuffer)
          accurateDiagnosticMilliseconds = diagnosticStart.duration(to: .now)
            .milliseconds
          accurateDiagnosticLikelihood = accurate.likelihood
        } else {
          accurateDiagnosticMilliseconds = nil
          accurateDiagnosticLikelihood = nil
        }
        let imagePath: String?
        if arguments.writesImages {
          let fileName = "\(sample.id)-\(variant.id).jpg"
          try renderer.writeJPEG(
            pixelBuffer,
            to: arguments.outputDirectory.appending(path: fileName)
          )
          imagePath = "images/\(fileName)"
        } else {
          imagePath = nil
        }
        results.append(
          SubtitleBenchmarkReport.SampleResult(
            sampleID: sample.id,
            variantID: variant.id,
            language: subtitleSource?.language,
            style: variant.style,
            tags: sample.tags,
            requestedTimeSeconds: sample.sourceTimeSeconds,
            actualTimeSeconds: actualTime,
            expectedDetection: expected,
            detected: detected,
            likelihood: analysis.likelihood,
            usedAccurateRecognition: analysis.usedAccurateRecognition,
            analysisMilliseconds: elapsed,
            heuristicSuspicious: heuristicDiagnostics.isSuspicious,
            heuristicTotalEdgeCount: heuristicDiagnostics.totalEdgeCount,
            heuristicConcentration: heuristicDiagnostics.concentration,
            heuristicWindowDensity: heuristicDiagnostics.windowDensity,
            heuristicBrightStrokeCount: heuristicDiagnostics.brightStrokeCount,
            heuristicBrightStrokeConcentration:
              heuristicDiagnostics.brightStrokeConcentration,
            heuristicBrightStrokeWindowDensity:
              heuristicDiagnostics.brightStrokeWindowDensity,
            accurateDiagnosticLikelihood: accurateDiagnosticLikelihood,
            accurateDiagnosticMilliseconds: accurateDiagnosticMilliseconds,
            imagePath: imagePath
          )
        )
      }
    }

    let variantSummaries = manifest.variants.map { variant in
      SubtitleBenchmarkReport.VariantSummary(
        variantID: variant.id,
        language: variant.subtitleSourceID.flatMap {
          subtitleSources[$0]?.language
        },
        style: variant.style,
        summary: SubtitleBenchmarkReport.Summary(
          samples: results.filter { $0.variantID == variant.id }
        )
      )
    }
    let report = SubtitleBenchmarkReport(
      schemaVersion: 1,
      generatedAt: Date(),
      benchmarkIdentifier: manifest.identifier,
      source: manifest.source,
      environment: .current,
      configuration: SubtitleBenchmarkReport.Configuration(
        rendererVersion: manifest.rendererVersion,
        decisionRule: "likelihood > 0",
        maximumFrameWidth: 1_280,
        maximumFrameHeight: 720,
        warmupCount: 1,
        imageOutput: arguments.writesImages ? "JPEG quality 0.82" : "disabled"
      ),
      summary: SubtitleBenchmarkReport.Summary(samples: results),
      variantSummaries: variantSummaries,
      samples: results,
      notes: [
        "The source video and subtitle files are checksum-locked and are not committed.",
        "Rendered variants use official subtitle text and timing over decoded live-action frames.",
        "Clean and rendered variants share the same decoded source frame.",
        "One unreported clean-frame analysis warms Vision before timings are recorded.",
        "Accurate diagnostic retries run only after measured false negatives and are excluded from primary timings.",
      ]
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(report)
    try FileManager.default.createDirectory(
      at: arguments.reportURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: arguments.reportURL, options: .atomic)

    printSummary(report, reportURL: arguments.reportURL)
  }

  private static func repositoryURL(_ path: String, root: URL) throws -> URL {
    let url = URL(filePath: path, relativeTo: root).standardizedFileURL
    guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else {
      throw SubtitleBenchmarkError.invalidManifest(
        "Manifest path escapes the repository: \(path)"
      )
    }
    return url
  }

  private static func printSummary(
    _ report: SubtitleBenchmarkReport,
    reportURL: URL
  ) {
    let summary = report.summary
    let recall = summary.recall.map { String(format: "%.1f%%", $0 * 100) }
      ?? "n/a"
    let specificity = summary.specificity.map {
      String(format: "%.1f%%", $0 * 100)
    } ?? "n/a"
    print("samples: \(summary.sampleCount)")
    print("evaluated samples: \(summary.evaluatedSampleCount)")
    print("ambiguous samples: \(summary.ambiguousCount)")
    print("recall: \(recall)")
    print("specificity: \(specificity)")
    print("false negatives: \(summary.falseNegativeCount)")
    print("false positives: \(summary.falsePositiveCount)")
    print(
      "median subtitle analysis: "
        + String(format: "%.2f ms", summary.medianAnalysisMilliseconds)
    )
    print("report: \(reportURL.path)")
  }
}

private extension Duration {
  var milliseconds: Double {
    let components = self.components
    return Double(components.seconds) * 1_000
      + Double(components.attoseconds) / 1_000_000_000_000_000
  }
}
