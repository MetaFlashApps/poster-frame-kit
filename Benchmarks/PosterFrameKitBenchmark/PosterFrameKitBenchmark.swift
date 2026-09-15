@preconcurrency import AVFoundation
import CoreGraphics
import Darwin
import Foundation
import PosterFrameKit
import PosterFrameKitBenchmarkSupport

@main
private struct PosterFrameKitBenchmark {
  static func main() async {
    do {
      let arguments = try BenchmarkArguments(CommandLine.arguments)
      if arguments.isWorker {
        try await runWorker(arguments)
      } else {
        try await runCoordinator(arguments)
      }
    } catch {
      FileHandle.standardError.write(
        Data("Benchmark failed: \(error.localizedDescription)\n".utf8))
      exit(EXIT_FAILURE)
    }
  }

  private static func runCoordinator(_ arguments: BenchmarkArguments) async throws {
    let fixtureURL =
      arguments.fixtureURL
      ?? GeneratedFixture.url(for: arguments.generatedFixtureVariant)
    if arguments.fixtureURL == nil {
      try await GeneratedFixture.makeIfNeeded(
        at: fixtureURL,
        variant: arguments.generatedFixtureVariant
      )
    }
    let fixtureDescription = try await describeFixture(
      at: fixtureURL,
      generatedVariant: arguments.fixtureURL == nil
        ? arguments.generatedFixtureVariant
        : nil
    )

    var measurements: [LaneMeasurement] = []
    for laneCount in arguments.laneCounts {
      var processCold: [WorkerMeasurement] = []
      for _ in 0..<arguments.coldRuns {
        processCold.append(
          try runSubprocessWorker(
            fixtureURL: fixtureURL,
            laneCount: laneCount,
            candidateCount: arguments.candidateCount,
            excludesMidroll: arguments.excludesMidroll,
            avoidsSubtitles: arguments.avoidsSubtitles,
            subtitleCandidateCount: arguments.subtitleCandidateCount,
            subtitleMaximumPenalty: arguments.subtitleMaximumPenalty,
            prefersFaces: arguments.prefersFaces,
            faceCandidateCount: arguments.faceCandidateCount,
            faceMaximumBonus: arguments.faceMaximumBonus,
            prefersAesthetics: arguments.prefersAesthetics,
            aestheticCandidateCount: arguments.aestheticCandidateCount,
            aestheticMaximumAdjustment: arguments.aestheticMaximumAdjustment,
            warmupCount: 0
          )
        )
      }
      var warm: [WorkerMeasurement] = []
      for _ in 0..<arguments.warmRuns {
        warm.append(
          try runSubprocessWorker(
            fixtureURL: fixtureURL,
            laneCount: laneCount,
            candidateCount: arguments.candidateCount,
            excludesMidroll: arguments.excludesMidroll,
            avoidsSubtitles: arguments.avoidsSubtitles,
            subtitleCandidateCount: arguments.subtitleCandidateCount,
            subtitleMaximumPenalty: arguments.subtitleMaximumPenalty,
            prefersFaces: arguments.prefersFaces,
            faceCandidateCount: arguments.faceCandidateCount,
            faceMaximumBonus: arguments.faceMaximumBonus,
            prefersAesthetics: arguments.prefersAesthetics,
            aestheticCandidateCount: arguments.aestheticCandidateCount,
            aestheticMaximumAdjustment: arguments.aestheticMaximumAdjustment,
            warmupCount: 1
          )
        )
      }
      measurements.append(
        LaneMeasurement(
          decoderLaneCount: laneCount,
          processColdRuns: processCold,
          processWarmRuns: warm,
          processColdMedianMilliseconds: median(
            processCold.map(\.endToEndMilliseconds).sorted()
          ),
          processWarmMedianMilliseconds: median(
            warm.map(\.endToEndMilliseconds).sorted()
          ),
          processColdMedianPeakResidentBytes: medianBytes(
            processCold.map(\.memory.sampledPeakResidentBytes).sorted()
          ),
          processWarmMedianPeakResidentBytes: medianBytes(
            warm.map(\.memory.sampledPeakResidentBytes).sorted()
          ),
          processColdMedianPeakResidentIncreaseBytes: medianBytes(
            processCold.map(\.memory.peakResidentIncreaseBytes).sorted()
          ),
          processWarmMedianPeakResidentIncreaseBytes: medianBytes(
            warm.map(\.memory.peakResidentIncreaseBytes).sorted()
          )
        )
      )
    }

    let report = BenchmarkReport(
      schemaVersion: 7,
      label: arguments.label,
      generatedAt: ISO8601DateFormatter().string(from: Date()),
      system: .current(),
      fixture: fixtureDescription,
      configuration: BenchmarkConfiguration(
        profile: "animation",
        candidateCount: arguments.candidateCount,
        searchRange: [0.08, 0.90],
        excludedRanges: arguments.excludesMidroll
          ? [[0.46, 0.54]]
          : [],
        outputWidth: 1_280,
        outputHeight: 720,
        exactTimeTolerance: true,
        avoidsSubtitles: arguments.avoidsSubtitles,
        subtitleCandidateCount: arguments.avoidsSubtitles
          ? arguments.subtitleCandidateCount
          : nil,
        subtitleMaximumPenalty: arguments.avoidsSubtitles
          ? arguments.subtitleMaximumPenalty
          : nil,
        prefersFaces: arguments.prefersFaces,
        faceCandidateCount: arguments.prefersFaces
          ? arguments.faceCandidateCount
          : nil,
        faceMaximumBonus: arguments.prefersFaces
          ? arguments.faceMaximumBonus
          : nil,
        prefersAesthetics: arguments.prefersAesthetics,
        aestheticCandidateCount: arguments.prefersAesthetics
          ? arguments.aestheticCandidateCount
          : nil,
        aestheticMaximumAdjustment: arguments.prefersAesthetics
          ? arguments.aestheticMaximumAdjustment
          : nil,
        residentMemorySamplingIntervalMilliseconds: 2
      ),
      measurements: measurements,
      notes: [
        "Each measurement runs in a worker process; fixture generation is excluded.",
        "Each processColdRun uses a fresh worker without a selection warm-up.",
        "Each processWarmRun uses a fresh worker and performs one unmeasured selection before measurement.",
        "The operating system filesystem cache is shared and uncontrolled; process-cold does not mean disk-cache-cold.",
        "Resident memory is sampled every 2 ms only during the measured selection; peakResidentIncreaseBytes is relative to that selection's starting resident size.",
        "Stage durations are measured directly and are cumulative across decoder lanes.",
        "Subtitle analysis inspects only the lower third of the leading candidates when enabled.",
        "Face analysis inspects only the bounded leading candidate group when enabled.",
        "Aesthetic analysis uses Vision revision 1 on supported operating systems and inspects only the bounded leading candidate group when enabled.",
      ]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(report)

    if let outputURL = arguments.outputURL {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try data.write(to: outputURL, options: .atomic)
      print("Wrote benchmark report to \(outputURL.path)")
    } else {
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }

    for measurement in measurements {
      print(
        "candidates=\(arguments.candidateCount) "
          + "lanes=\(measurement.decoderLaneCount) "
          + "subtitles=\(arguments.avoidsSubtitles ? "on" : "off") "
          + "faces=\(arguments.prefersFaces ? "on" : "off") "
          + "aesthetics=\(arguments.prefersAesthetics ? "on" : "off") "
          + "cold-median=\(measurement.processColdMedianMilliseconds.formatted(.number.precision(.fractionLength(2)))) ms "
          + "warm-median=\(measurement.processWarmMedianMilliseconds.formatted(.number.precision(.fractionLength(2)))) ms "
          + "warm-peak=\(ByteCountFormatter.string(fromByteCount: Int64(measurement.processWarmMedianPeakResidentBytes), countStyle: .memory)) "
          + "warm-peak-delta=\(ByteCountFormatter.string(fromByteCount: Int64(measurement.processWarmMedianPeakResidentIncreaseBytes), countStyle: .memory)) "
          + "time=\(measurement.processColdRuns[0].selectedTimeSeconds.formatted(.number.precision(.fractionLength(3)))) s"
      )
    }
  }

  private static func describeFixture(
    at url: URL,
    generatedVariant: GeneratedFixtureVariant?
  ) async throws -> BenchmarkFixtureDescription {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw BenchmarkError.fixtureCreationFailed("The benchmark fixture has no video track.")
    }
    let naturalSize = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let displaySize = naturalSize.applying(transform)
    let frameRate = try await track.load(.nominalFrameRate)
    let descriptions = try await track.load(.formatDescriptions)
    let codec =
      descriptions.first.map {
        fourCharacterCode(CMFormatDescriptionGetMediaSubType($0))
      } ?? "unknown"
    return BenchmarkFixtureDescription(
      identifier: generatedVariant?.identifier ?? url.lastPathComponent,
      codec: codec,
      width: Int(abs(displaySize.width).rounded()),
      height: Int(abs(displaySize.height).rounded()),
      framesPerSecond: Int(frameRate.rounded()),
      durationSeconds: duration.seconds,
      generated: generatedVariant != nil
    )
  }

  private static func runWorker(_ arguments: BenchmarkArguments) async throws {
    guard let fixtureURL = arguments.fixtureURL,
      let laneCount = arguments.laneCounts.first
    else {
      throw BenchmarkError.invalidArguments("A worker requires a fixture and lane count.")
    }
    let options = PosterFrameOptions(
      maximumFramesExamined: arguments.candidateCount,
      excludedRanges: arguments.excludesMidroll ? [0.46...0.54] : [],
      profile: .animation,
      subtitleAvoidance: arguments.avoidsSubtitles
        ? PosterFrameSubtitleOptions(
          candidateCount: arguments.subtitleCandidateCount,
          maximumPenalty: arguments.subtitleMaximumPenalty
        )
        : nil,
      facePreference: arguments.prefersFaces
        ? PosterFrameFaceOptions(
          candidateCount: arguments.faceCandidateCount,
          maximumBonus: arguments.faceMaximumBonus
        )
        : nil,
      aestheticPreference: arguments.prefersAesthetics
        ? PosterFrameAestheticOptions(
          candidateCount: arguments.aestheticCandidateCount,
          maximumAdjustment: arguments.aestheticMaximumAdjustment
        )
        : nil,
      outputSize: CGSize(width: 1_280, height: 720)
    )
    for _ in 0..<arguments.warmupCount {
      _ = try await PosterFrameKit.benchmarkBestFrame(
        in: fixtureURL,
        options: options,
        decoderLaneCount: laneCount
      )
    }

    let measured = try await measureSelectionMemory {
      let start = ContinuousClock.now
      let selection = try await PosterFrameKit.benchmarkBestFrame(
        in: fixtureURL,
        options: options,
        decoderLaneCount: laneCount
      )
      return (
        selection: selection,
        endToEndMilliseconds: milliseconds(start.duration(to: .now))
      )
    }
    let selection = measured.value.selection
    let measurement = WorkerMeasurement(
      endToEndMilliseconds: measured.value.endToEndMilliseconds,
      selectedTimeSeconds: selection.result.time.seconds,
      score: selection.result.score,
      adjustedScore: selection.result.adjustedScore,
      subtitlePenalty: selection.result.subtitlePenalty,
      faceCompositionBonus: selection.result.faceCompositionBonus,
      aestheticScore: selection.result.aestheticScore,
      isUtilityFrame: selection.result.isUtilityFrame,
      aestheticAdjustment: selection.result.aestheticAdjustment,
      memory: measured.memory,
      performance: selection.performance
    )
    let encoder = JSONEncoder()
    FileHandle.standardOutput.write(try encoder.encode(measurement))
  }

  private static func runSubprocessWorker(
    fixtureURL: URL,
    laneCount: Int,
    candidateCount: Int,
    excludesMidroll: Bool,
    avoidsSubtitles: Bool,
    subtitleCandidateCount: Int,
    subtitleMaximumPenalty: Double,
    prefersFaces: Bool,
    faceCandidateCount: Int,
    faceMaximumBonus: Double,
    prefersAesthetics: Bool,
    aestheticCandidateCount: Int,
    aestheticMaximumAdjustment: Double,
    warmupCount: Int
  ) throws -> WorkerMeasurement {
    let process = Process()
    guard let executableURL = Bundle.main.executableURL else {
      throw BenchmarkError.workerFailed("Unable to locate the benchmark executable.")
    }
    process.executableURL = executableURL
    var processArguments = [
      "--worker",
      "--fixture", fixtureURL.path,
      "--lanes", String(laneCount),
      "--candidates", String(candidateCount),
      "--warmup-count", String(warmupCount),
    ]
    if excludesMidroll {
      processArguments.append("--exclude-midroll")
    }
    if avoidsSubtitles {
      processArguments.append("--avoid-subtitles")
      processArguments.append(contentsOf: [
        "--subtitle-candidates", String(subtitleCandidateCount),
        "--subtitle-maximum-penalty", String(subtitleMaximumPenalty),
      ])
    }
    if prefersFaces {
      processArguments.append("--prefer-faces")
      processArguments.append(contentsOf: [
        "--face-candidates", String(faceCandidateCount),
        "--face-maximum-bonus", String(faceMaximumBonus),
      ])
    }
    if prefersAesthetics {
      processArguments.append("--prefer-aesthetics")
      processArguments.append(contentsOf: [
        "--aesthetic-candidates", String(aestheticCandidateCount),
        "--aesthetic-maximum-adjustment",
        String(aestheticMaximumAdjustment),
      ])
    }
    process.arguments = processArguments
    let standardOutput = Pipe()
    let standardError = Pipe()
    process.standardOutput = standardOutput
    process.standardError = standardError
    try process.run()
    process.waitUntilExit()
    let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = standardError.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      throw BenchmarkError.workerFailed(
        String(data: errorOutput, encoding: .utf8)
          ?? "Worker exited with status \(process.terminationStatus)."
      )
    }
    return try JSONDecoder().decode(WorkerMeasurement.self, from: output)
  }
}
