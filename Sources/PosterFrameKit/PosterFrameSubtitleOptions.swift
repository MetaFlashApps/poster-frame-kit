/// Configuration for optional subtitle-aware candidate re-ranking.
///
/// PosterFrameKit first completes its normal deterministic ranking. When these
/// options are present, only the strongest leading candidates receive the
/// additional subtitle analysis. The default selection path performs no text
/// analysis and has no subtitle-related runtime cost.
public struct PosterFrameSubtitleOptions: Equatable, Sendable {
  /// Maximum number of leading candidates inspected for subtitles.
  public var candidateCount: Int

  /// Largest score reduction applied to a subtitle-like candidate.
  ///
  /// The value is expressed in the same normalized `0...1` scale as a
  /// poster-frame score. Zero disables the refinement work.
  public var maximumPenalty: Double

  /// Creates subtitle-aware re-ranking options.
  ///
  /// - Parameters:
  ///   - candidateCount: Maximum number of leading candidates to inspect.
  ///   - maximumPenalty: Largest normalized score reduction to apply.
  public init(
    candidateCount: Int = 8,
    maximumPenalty: Double = 0.08
  ) {
    self.candidateCount = candidateCount
    self.maximumPenalty = maximumPenalty
  }
}

extension PosterFrameSubtitleOptions {
  func normalized(maximumFramesExamined: Int) throws -> Self {
    guard candidateCount > 0 else {
      throw PosterFrameError.invalidOptions(
        "subtitleAvoidance.candidateCount must be greater than zero"
      )
    }
    guard maximumPenalty.isFinite, (0...1).contains(maximumPenalty) else {
      throw PosterFrameError.invalidOptions(
        "subtitleAvoidance.maximumPenalty must be finite and between zero and one"
      )
    }

    var result = self
    result.candidateCount = min(candidateCount, maximumFramesExamined)
    return result
  }
}
