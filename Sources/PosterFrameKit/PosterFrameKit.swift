@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

/// Namespace for PosterFrameKit's public selection and evaluation API.
public enum PosterFrameKit {
  /// Selects the strongest poster frame from a local video URL.
  ///
  /// - Parameters:
  ///   - url: Local video URL supported by AVFoundation.
  ///   - options: Sampling, scoring, and output configuration.
  /// - Returns: The selected image, actual timestamp, base score, optional
  ///   candidate refinements, and metrics.
  /// - Throws: ``PosterFrameError`` or an AVFoundation decoding error.
  public static func bestFrame(
    in url: URL,
    options: PosterFrameOptions = PosterFrameOptions()
  ) async throws -> PosterFrameResult {
    try await selectBestFrame(
      in: url,
      options: options,
      decoderLaneCount: recommendedAVFoundationDecoderLaneCount,
      performanceRecorder: nil
    )
  }

  package static func benchmarkBestFrame(
    in url: URL,
    options: PosterFrameOptions,
    decoderLaneCount: Int = 1
  ) async throws -> PosterFrameBenchmarkSelection {
    let performanceRecorder = PosterFramePerformanceRecorder()
    let result = try await selectBestFrame(
      in: url,
      options: options,
      decoderLaneCount: decoderLaneCount,
      performanceRecorder: performanceRecorder
    )
    return PosterFrameBenchmarkSelection(
      result: result,
      performance: await performanceRecorder.snapshot(),
      decoderLaneCount: decoderLaneCount
    )
  }

  private static func selectBestFrame(
    in url: URL,
    options: PosterFrameOptions,
    decoderLaneCount: Int,
    performanceRecorder: PosterFramePerformanceRecorder?
  ) async throws -> PosterFrameResult {
    let options = try options.normalized()
    try PosterFrameCancellation.check()

    let asset = AVURLAsset(url: url)
    let metadataSource = AVFoundationFrameSource(
      asset: asset,
      performanceRecorder: performanceRecorder
    )
    let duration: CMTime
    duration = try await PosterFrameCancellation.map {
      try await metadataSource.duration
    }
    let timestamps = try CandidatePlanner.timestamps(
      duration: duration,
      options: options
    )
    let dependencies = CandidateAnalysisDependencies.live(options: options)
    let accumulator = CandidateAccumulator(
      options: options,
      dependencies: dependencies,
      performanceRecorder: performanceRecorder
    )
    let laneCount = min(max(decoderLaneCount, 1), timestamps.count)
    if laneCount == 1 {
      for (candidateIndex, timestamp) in timestamps.enumerated() {
        try PosterFrameCancellation.check()
        let sample: PosterFrameSample
        do {
          sample = try await PosterFrameCancellation.map {
            try await metadataSource.frame(
              at: timestamp,
              maximumSize: options.outputSize
            )
          }
        } catch PosterFrameError.cancelled {
          throw PosterFrameError.cancelled
        } catch {
          await accumulator.recordDecodingError(
            error,
            candidateIndex: candidateIndex
          )
          continue
        }
        try await accumulator.submit(sample)
      }
      return try await accumulator.result()
    }

    let chunkSize = (timestamps.count + laneCount - 1) / laneCount

    try await withThrowingTaskGroup(of: Void.self) { group in
      var laneIndex = 0
      for startIndex in stride(
        from: 0,
        to: timestamps.count,
        by: chunkSize
      ) {
        let endIndex = min(startIndex + chunkSize, timestamps.count)
        let indexedTimes = (startIndex..<endIndex).map {
          (candidateIndex: $0, time: timestamps[$0])
        }
        let source: AVFoundationFrameSource
        if laneIndex == 0 {
          source = metadataSource
        } else {
          source = AVFoundationFrameSource(
            asset: asset,
            knownDuration: duration,
            performanceRecorder: performanceRecorder
          )
        }
        laneIndex += 1
        group.addTask {
          for indexedTime in indexedTimes {
            try PosterFrameCancellation.check()
            let sample: PosterFrameSample
            do {
              sample = try await PosterFrameCancellation.map {
                try await source.frame(
                  at: indexedTime.time,
                  maximumSize: options.outputSize
                )
              }
            } catch PosterFrameError.cancelled {
              throw PosterFrameError.cancelled
            } catch {
              await accumulator.recordDecodingError(
                error,
                candidateIndex: indexedTime.candidateIndex
              )
              continue
            }
            try await accumulator.submit(sample)
          }
        }
      }
      try await group.waitForAll()
    }

    return try await accumulator.result()
  }

  /// Selects the strongest poster frame from a custom frame source.
  ///
  /// Candidate timestamps are deterministic and identical actual timestamps
  /// are evaluated only once. Equal scores are resolved in favor of the
  /// earlier actual timestamp.
  ///
  /// - Parameters:
  ///   - source: Source used to decode requested frames.
  ///   - options: Sampling, scoring, and output configuration.
  /// - Returns: The selected image, actual timestamp, base score, optional
  ///   candidate refinements, and metrics.
  /// - Throws: ``PosterFrameError``, or an error produced by `source` while
  ///   reading its duration or decoding a frame.
  public static func bestFrame(
    from source: any PosterFrameSource,
    options: PosterFrameOptions = PosterFrameOptions()
  ) async throws -> PosterFrameResult {
    let options = try options.normalized()
    return try await selectBestFrame(
      from: source,
      options: options,
      dependencies: .live(options: options),
      performanceRecorder: nil
    )
  }

  static func selectBestFrame(
    from source: any PosterFrameSource,
    options: PosterFrameOptions,
    subtitleAnalyzer: (any SubtitleAnalyzing)? = nil,
    faceAnalyzer: (any FaceAnalyzing)? = nil,
    aestheticAnalyzer: (any AestheticAnalyzing)? = nil,
    performanceRecorder: PosterFramePerformanceRecorder? = nil
  ) async throws -> PosterFrameResult {
    let options = try options.normalized()
    return try await selectBestFrame(
      from: source,
      options: options,
      dependencies: CandidateAnalysisDependencies(
        subtitleAnalyzer: subtitleAnalyzer,
        faceAnalyzer: faceAnalyzer,
        aestheticAnalyzer: aestheticAnalyzer
      ),
      performanceRecorder: performanceRecorder
    )
  }

  private static func selectBestFrame(
    from source: any PosterFrameSource,
    options: PosterFrameOptions,
    dependencies: CandidateAnalysisDependencies,
    performanceRecorder: PosterFramePerformanceRecorder?
  ) async throws -> PosterFrameResult {
    try PosterFrameCancellation.check()

    let duration: CMTime
    duration = try await PosterFrameCancellation.map {
      try await source.duration
    }

    let timestamps = try CandidatePlanner.timestamps(
      duration: duration,
      options: options
    )
    let accumulator = CandidateAccumulator(
      options: options,
      dependencies: dependencies,
      performanceRecorder: performanceRecorder
    )

    for (candidateIndex, timestamp) in timestamps.enumerated() {
      try PosterFrameCancellation.check()

      let sample: PosterFrameSample
      do {
        sample = try await PosterFrameCancellation.map {
          try await source.frame(
            at: timestamp,
            maximumSize: options.outputSize
          )
        }
      } catch PosterFrameError.cancelled {
        throw PosterFrameError.cancelled
      } catch {
        await accumulator.recordDecodingError(
          error,
          candidateIndex: candidateIndex
        )
        continue
      }

      try await accumulator.submit(sample)
    }

    return try await accumulator.result()
  }

  /// Evaluates a decoded pixel buffer without sampling a video.
  ///
  /// - Parameters:
  ///   - pixelBuffer: Display-oriented frame data in a supported pixel format.
  ///   - profile: Scoring profile applied to the calculated metrics.
  /// - Returns: A normalized score and the metrics used to calculate it.
  /// - Throws: ``PosterFrameError/invalidOptions(_:)`` for invalid custom
  ///   profile weights, or a pixel-buffer analysis error.
  public static func evaluate(
    pixelBuffer: CVPixelBuffer,
    profile: PosterFrameProfile = .general
  ) throws -> (score: Double, metrics: FrameMetrics) {
    let normalizedOptions = try PosterFrameOptions(profile: profile).normalized()
    var analyzer = FrameAnalyzer()
    let metrics = try analyzer.analyze(pixelBuffer)
    return (
      FrameScorer.score(metrics: metrics, profile: normalizedOptions.profile),
      metrics
    )
  }

  package static var recommendedAVFoundationDecoderLaneCount: Int {
    #if os(macOS)
      min(4, max(1, ProcessInfo.processInfo.activeProcessorCount / 2))
    #else
      1
    #endif
  }
}

package struct PosterFrameBenchmarkSelection: Sendable {
  package let result: PosterFrameResult
  package let performance: PosterFramePerformanceSnapshot
  package let decoderLaneCount: Int
}
