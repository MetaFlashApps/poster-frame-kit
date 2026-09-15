struct CandidateAnalysisDependencies: Sendable {
  let subtitleAnalyzer: (any SubtitleAnalyzing)?
  let faceAnalyzer: (any FaceAnalyzing)?
  let aestheticAnalyzer: (any AestheticAnalyzing)?

  static func live(options: PosterFrameOptions) -> Self {
    Self(
      subtitleAnalyzer: (options.subtitleAvoidance?.maximumPenalty ?? 0) > 0
        ? makeSubtitleAnalyzer()
        : nil,
      faceAnalyzer: (options.facePreference?.maximumBonus ?? 0) > 0
        ? makeFaceAnalyzer()
        : nil,
      aestheticAnalyzer: (options.aestheticPreference?.maximumAdjustment ?? 0) > 0
        ? makeAestheticAnalyzer()
        : nil
    )
  }
}
