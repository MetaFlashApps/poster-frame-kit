import os

struct CandidateRefinementPipeline {
  private static let logger = Logger(
    subsystem: "com.metaflash.PosterFrameKit",
    category: "CandidateRefinement"
  )

  private let options: PosterFrameOptions
  private let dependencies: CandidateAnalysisDependencies
  private let performanceRecorder: PosterFramePerformanceRecorder?

  init(
    options: PosterFrameOptions,
    dependencies: CandidateAnalysisDependencies,
    performanceRecorder: PosterFramePerformanceRecorder?
  ) {
    self.options = options
    self.dependencies = dependencies
    self.performanceRecorder = performanceRecorder
  }

  var isActive: Bool {
    hasActiveSubtitleRefinement
      || hasActiveFaceRefinement
      || hasActiveAestheticRefinement
  }

  var retainedCandidateCount: Int {
    max(
      max(
        hasActiveSubtitleRefinement
          ? options.subtitleAvoidance?.candidateCount ?? 0
          : 0,
        hasActiveFaceRefinement
          ? options.facePreference?.candidateCount ?? 0
          : 0
      ),
      hasActiveAestheticRefinement
        ? options.aestheticPreference?.candidateCount ?? 0
        : 0
    )
  }

  func rank(
    _ candidates: [EvaluatedCandidate],
    fallback: EvaluatedCandidate
  ) async throws -> [RefinedCandidate] {
    let candidates = candidates.isEmpty ? [fallback] : candidates
    var ranked = candidates.map { RefinedCandidate(candidate: $0) }

    ranked = try await applyFacePreference(to: ranked, original: candidates)
    ranked = try await applySubtitleAvoidance(to: ranked)
    ranked = try await applyAestheticPreference(to: ranked)
    return ranked
  }

  private var hasActiveSubtitleRefinement: Bool {
    guard let subtitleAvoidance = options.subtitleAvoidance else {
      return false
    }
    return subtitleAvoidance.maximumPenalty > 0
      && dependencies.subtitleAnalyzer != nil
  }

  private var hasActiveFaceRefinement: Bool {
    guard let facePreference = options.facePreference else {
      return false
    }
    return facePreference.maximumBonus > 0
      && dependencies.faceAnalyzer != nil
  }

  private var hasActiveAestheticRefinement: Bool {
    guard let aestheticPreference = options.aestheticPreference else {
      return false
    }
    return aestheticPreference.maximumAdjustment > 0
      && dependencies.aestheticAnalyzer != nil
  }

  private var needsCompleteRankingAfterFace: Bool {
    hasActiveSubtitleRefinement
      || hasActiveAestheticRefinement
  }

  private var needsCompleteRankingAfterSubtitle: Bool {
    hasActiveAestheticRefinement
  }

  private func applyFacePreference(
    to ranked: [RefinedCandidate],
    original candidates: [EvaluatedCandidate]
  ) async throws -> [RefinedCandidate] {
    guard hasActiveFaceRefinement,
      let faceOptions = options.facePreference,
      let faceAnalyzer = dependencies.faceAnalyzer
    else {
      return ranked
    }

    do {
      return try await FaceCandidateReranker(
        analyzer: faceAnalyzer,
        options: faceOptions,
        performanceRecorder: performanceRecorder
      ).rank(ranked, analyzeAll: needsCompleteRankingAfterFace)
    } catch {
      try PosterFrameCancellation.rethrowIfNeeded(error)
      Self.logger.debug(
        "Face analysis failed; using the ranking without face bonuses."
      )
      return candidates.map { RefinedCandidate(candidate: $0) }
    }
  }

  private func applySubtitleAvoidance(
    to ranked: [RefinedCandidate]
  ) async throws -> [RefinedCandidate] {
    guard hasActiveSubtitleRefinement,
      let subtitleOptions = options.subtitleAvoidance,
      let subtitleAnalyzer = dependencies.subtitleAnalyzer
    else {
      return ranked
    }

    do {
      return try await SubtitleCandidateReranker(
        analyzer: subtitleAnalyzer,
        options: subtitleOptions,
        performanceRecorder: performanceRecorder
      ).rank(ranked, analyzeAll: needsCompleteRankingAfterSubtitle)
    } catch {
      try PosterFrameCancellation.rethrowIfNeeded(error)
      Self.logger.debug(
        "Subtitle analysis failed; using the ranking without subtitle penalties."
      )
      return ranked
    }
  }

  private func applyAestheticPreference(
    to ranked: [RefinedCandidate]
  ) async throws -> [RefinedCandidate] {
    guard hasActiveAestheticRefinement,
      let aestheticOptions = options.aestheticPreference,
      let aestheticAnalyzer = dependencies.aestheticAnalyzer
    else {
      return ranked
    }

    do {
      return try await AestheticCandidateReranker(
        analyzer: aestheticAnalyzer,
        options: aestheticOptions,
        performanceRecorder: performanceRecorder
      ).rank(ranked, analyzeAll: false)
    } catch {
      try PosterFrameCancellation.rethrowIfNeeded(error)
      Self.logger.debug(
        "Aesthetics analysis failed; using the ranking without aesthetics adjustments."
      )
      return ranked
    }
  }
}
