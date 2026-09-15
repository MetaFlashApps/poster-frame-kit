/// Configuration for optional face-aware candidate re-ranking.
///
/// PosterFrameKit first completes its normal deterministic ranking. When these
/// options are present, only a bounded group of leading candidates receives
/// additional face detection. A sufficiently confident detected face can
/// improve a candidate's ranking, while a frame without a reliable detection
/// receives no penalty.
public struct PosterFrameFaceOptions: Equatable, Sendable {
  /// Maximum number of leading candidates inspected for faces.
  public var candidateCount: Int

  /// Largest score increase applied for strong face composition.
  ///
  /// The value is expressed in the same normalized `0...1` scale as a
  /// poster-frame score. Zero disables the refinement work.
  public var maximumBonus: Double

  /// Creates face-aware re-ranking options.
  ///
  /// - Parameters:
  ///   - candidateCount: Maximum number of leading candidates to inspect.
  ///   - maximumBonus: Largest normalized score increase to apply.
  public init(
    candidateCount: Int = 8,
    maximumBonus: Double = 0.04
  ) {
    self.candidateCount = candidateCount
    self.maximumBonus = maximumBonus
  }
}

extension PosterFrameFaceOptions {
  func normalized(maximumFramesExamined: Int) throws -> Self {
    guard candidateCount > 0 else {
      throw PosterFrameError.invalidOptions(
        "facePreference.candidateCount must be greater than zero"
      )
    }
    guard maximumBonus.isFinite, (0...1).contains(maximumBonus) else {
      throw PosterFrameError.invalidOptions(
        "facePreference.maximumBonus must be finite and between zero and one"
      )
    }

    var result = self
    result.candidateCount = min(candidateCount, maximumFramesExamined)
    return result
  }
}
