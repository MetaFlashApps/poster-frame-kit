/// Configuration for optional aesthetic candidate re-ranking.
///
/// PosterFrameKit first completes its normal deterministic ranking and any
/// enabled content refinements. When these options are present on a supported
/// operating system, Apple Vision supplies the aesthetic base ranking for a
/// bounded group while face and subtitle adjustments remain independent.
public struct PosterFrameAestheticOptions: Equatable, Sendable {
  /// Maximum number of leading candidates inspected for aesthetics.
  public var candidateCount: Int

  /// Largest absolute change needed to align the deterministic base score
  /// with Vision's normalized aesthetics score.
  ///
  /// The value is expressed in the same normalized `0...1` scale as a
  /// poster-frame score. Zero disables the refinement work.
  public var maximumAdjustment: Double

  /// Creates aesthetic re-ranking options.
  ///
  /// - Parameters:
  ///   - candidateCount: Maximum number of leading candidates to inspect.
  ///   - maximumAdjustment: Largest absolute score change to apply.
  public init(
    candidateCount: Int = 24,
    maximumAdjustment: Double = 1
  ) {
    self.candidateCount = candidateCount
    self.maximumAdjustment = maximumAdjustment
  }
}

extension PosterFrameAestheticOptions {
  func normalized(maximumFramesExamined: Int) throws -> Self {
    guard candidateCount > 0 else {
      throw PosterFrameError.invalidOptions(
        "aestheticPreference.candidateCount must be greater than zero"
      )
    }
    guard maximumAdjustment.isFinite,
      (0...1).contains(maximumAdjustment)
    else {
      throw PosterFrameError.invalidOptions(
        "aestheticPreference.maximumAdjustment must be finite and between zero and one"
      )
    }

    var result = self
    result.candidateCount = min(candidateCount, maximumFramesExamined)
    return result
  }
}
