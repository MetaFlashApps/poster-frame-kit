import CoreGraphics

struct PosterFrameResultFactory {
  let performanceRecorder: PosterFramePerformanceRecorder?

  func make(
    from refinedCandidate: RefinedCandidate
  ) async throws -> PosterFrameResult {
    let candidate = refinedCandidate.candidate
    let resultStart = ContinuousClock.now
    let image = try PixelBufferImageConverter.image(
      from: candidate.pixelBuffer
    )
    if let performanceRecorder {
      await performanceRecorder.recordResultImageConversion(
        resultStart.duration(to: .now)
      )
    }

    return PosterFrameResult(
      image: image,
      time: candidate.time,
      score: candidate.score,
      metrics: candidate.metrics,
      subtitlePenalty: refinedCandidate.subtitlePenalty,
      faceCompositionBonus: refinedCandidate.faceCompositionBonus,
      aestheticScore: refinedCandidate.aestheticScore,
      isUtilityFrame: refinedCandidate.isUtilityFrame,
      aestheticAdjustment: refinedCandidate.aestheticAdjustment
    )
  }
}
