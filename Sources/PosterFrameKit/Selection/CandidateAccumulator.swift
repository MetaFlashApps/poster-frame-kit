actor CandidateAccumulator {
  private let options: PosterFrameOptions
  private let refinementPipeline: CandidateRefinementPipeline
  private let resultFactory: PosterFrameResultFactory
  private let performanceRecorder: PosterFramePerformanceRecorder?
  private var analyzer = FrameAnalyzer()
  private var pool: CandidatePool

  init(
    options: PosterFrameOptions,
    dependencies: CandidateAnalysisDependencies,
    performanceRecorder: PosterFramePerformanceRecorder?
  ) {
    self.options = options
    self.performanceRecorder = performanceRecorder

    let refinementPipeline = CandidateRefinementPipeline(
      options: options,
      dependencies: dependencies,
      performanceRecorder: performanceRecorder
    )
    self.refinementPipeline = refinementPipeline
    self.resultFactory = PosterFrameResultFactory(
      performanceRecorder: performanceRecorder
    )
    self.pool = CandidatePool(
      retainedCandidateCount: refinementPipeline.retainedCandidateCount
    )
  }

  func recordDecodingError(_ error: any Error, candidateIndex: Int) {
    pool.recordDecodingError(error, candidateIndex: candidateIndex)
  }

  func submit(_ sample: PosterFrameSample) async throws {
    try PosterFrameCancellation.check()
    guard pool.register(actualTime: sample.actualTime) else {
      return
    }

    let analysisStart = ContinuousClock.now
    let metrics = try analyzer.analyze(sample.pixelBuffer)
    let candidate = EvaluatedCandidate(
      pixelBuffer: sample.pixelBuffer,
      time: sample.actualTime,
      score: FrameScorer.score(metrics: metrics, profile: options.profile),
      metrics: metrics
    )
    pool.insert(candidate)
    if let performanceRecorder {
      await performanceRecorder.recordAnalysisAndRanking(
        analysisStart.duration(to: .now)
      )
    }
  }

  func result() async throws -> PosterFrameResult {
    try PosterFrameCancellation.check()
    guard let bestCandidate = pool.bestCandidate else {
      if let lastDecodingError = pool.lastDecodingError {
        throw lastDecodingError.error
      }
      throw PosterFrameError.noCandidateFrames
    }

    if refinementPipeline.isActive {
      return try await refinedResult(fallback: bestCandidate)
    }

    return try await resultFactory.make(
      from: RefinedCandidate(candidate: bestCandidate)
    )
  }

  private func refinedResult(
    fallback: EvaluatedCandidate
  ) async throws -> PosterFrameResult {
    let ranked = try await refinementPipeline.rank(
      pool.refinementCandidates,
      fallback: fallback
    )
    return try await resultFactory.make(
      from: ranked.first ?? RefinedCandidate(candidate: fallback)
    )
  }
}
