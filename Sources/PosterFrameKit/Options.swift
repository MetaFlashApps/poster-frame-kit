import CoreGraphics
import Foundation

/// Configuration for poster-frame sampling, analysis, and output.
///
/// Options remain mutable for convenient configuration. Call ``normalized()``
/// before using them in a custom pipeline. PosterFrameKit's selection methods
/// perform the same validation automatically.
public struct PosterFrameOptions: Equatable, Sendable {
  /// Normalized portion of the video to search, where `0` is the beginning
  /// and `1` is the end.
  public var searchRange: ClosedRange<Double>

  /// The largest number of candidate timestamps to request.
  public var maximumFramesExamined: Int

  /// Normalized portions of the video that candidate sampling skips.
  ///
  /// Exclusions are useful for predictable content such as a midroll title
  /// card. They are intersected with `0...1`, sorted, and merged during
  /// normalization.
  public var excludedRanges: [ClosedRange<Double>]

  /// The scoring profile used to rank decoded frames.
  public var profile: PosterFrameProfile

  /// Optional subtitle-aware re-ranking configuration.
  ///
  /// A value enables best-effort analysis of a small leading candidate set.
  /// `nil` keeps subtitle analysis completely disabled.
  public var subtitleAvoidance: PosterFrameSubtitleOptions?

  /// Optional face-aware re-ranking configuration.
  ///
  /// A value enables best-effort face detection for a small leading
  /// candidate set. `nil` keeps face analysis completely disabled.
  public var facePreference: PosterFrameFaceOptions?

  /// Optional aesthetic re-ranking configuration.
  ///
  /// A value enables best-effort Apple Vision aesthetics analysis for a
  /// bounded leading candidate set on supported operating systems. `nil`
  /// keeps aesthetics analysis completely disabled.
  public var aestheticPreference: PosterFrameAestheticOptions?

  /// The maximum pixel dimensions of decoded output, or `nil` for the
  /// source's natural size.
  ///
  /// Sources preserve aspect ratio and do not upscale solely to fill this
  /// bounding size.
  public var outputSize: CGSize?

  /// Creates poster-frame options.
  ///
  /// - Parameters:
  ///   - searchRange: Normalized portion of the video to inspect.
  ///   - maximumFramesExamined: Maximum number of requested candidates.
  ///   - excludedRanges: Normalized portions to omit from candidate sampling.
  ///   - profile: Profile used during scoring.
  ///   - subtitleAvoidance: Optional subtitle-aware re-ranking configuration.
  ///   - facePreference: Optional face-aware re-ranking configuration.
  ///   - aestheticPreference: Optional aesthetic re-ranking configuration.
  ///   - outputSize: Optional maximum output bounds in pixels.
  public init(
    searchRange: ClosedRange<Double> = 0.08...0.90,
    maximumFramesExamined: Int = 40,
    excludedRanges: [ClosedRange<Double>] = [],
    profile: PosterFrameProfile = .general,
    subtitleAvoidance: PosterFrameSubtitleOptions? = nil,
    facePreference: PosterFrameFaceOptions? = nil,
    aestheticPreference: PosterFrameAestheticOptions? = nil,
    outputSize: CGSize? = nil
  ) {
    self.searchRange = searchRange
    self.maximumFramesExamined = maximumFramesExamined
    self.excludedRanges = excludedRanges
    self.profile = profile
    self.subtitleAvoidance = subtitleAvoidance
    self.facePreference = facePreference
    self.aestheticPreference = aestheticPreference
    self.outputSize = outputSize
  }

  /// Returns a validated, canonical copy of these options.
  ///
  /// Search bounds are clamped to the normalized video interval `0...1`.
  /// Excluded ranges are intersected with that interval, sorted, and merged.
  /// Custom profile weights are scaled to a total of `1` while preserving
  /// their relative proportions. Calling this method on an already
  /// normalized value returns the same value.
  ///
  /// - Throws: ``PosterFrameError/invalidOptions(_:)`` when a value is not
  ///   finite, a candidate count is less than one, a subtitle penalty, face
  ///   bonus, or aesthetic adjustment is outside `0...1`, an output
  ///   dimension is not positive, or custom weights do not contain a
  ///   positive value.
  public func normalized() throws -> PosterFrameOptions {
    guard searchRange.lowerBound.isFinite,
      searchRange.upperBound.isFinite,
      searchRange.lowerBound <= searchRange.upperBound
    else {
      throw PosterFrameError.invalidOptions(
        "searchRange must have finite, ascending bounds"
      )
    }

    guard maximumFramesExamined > 0 else {
      throw PosterFrameError.invalidOptions(
        "maximumFramesExamined must be greater than zero"
      )
    }

    for excludedRange in excludedRanges {
      guard excludedRange.lowerBound.isFinite,
        excludedRange.upperBound.isFinite,
        excludedRange.lowerBound <= excludedRange.upperBound
      else {
        throw PosterFrameError.invalidOptions(
          "excludedRanges must have finite, ascending bounds"
        )
      }
    }

    if let outputSize {
      guard outputSize.width.isFinite,
        outputSize.height.isFinite,
        outputSize.width > 0,
        outputSize.height > 0
      else {
        throw PosterFrameError.invalidOptions(
          "outputSize must have finite, positive dimensions"
        )
      }
    }

    var result = self
    result.searchRange = clampedSearchRange
    result.excludedRanges = normalizedExcludedRanges
    result.subtitleAvoidance = try subtitleAvoidance?.normalized(
      maximumFramesExamined: maximumFramesExamined
    )
    result.facePreference = try facePreference?.normalized(
      maximumFramesExamined: maximumFramesExamined
    )
    result.aestheticPreference = try aestheticPreference?.normalized(
      maximumFramesExamined: maximumFramesExamined
    )

    guard
      !result.excludedRanges.contains(where: {
        $0.lowerBound <= result.searchRange.lowerBound
          && $0.upperBound >= result.searchRange.upperBound
      })
    else {
      throw PosterFrameError.invalidOptions(
        "excludedRanges must not cover the complete searchRange"
      )
    }

    if case .custom(let weights) = profile {
      result.profile = .custom(try weights.normalized())
    }

    return result
  }

  private var clampedSearchRange: ClosedRange<Double> {
    let lowerBound = min(max(searchRange.lowerBound, 0), 1)
    let upperBound = min(max(searchRange.upperBound, 0), 1)
    return lowerBound...upperBound
  }

  private var normalizedExcludedRanges: [ClosedRange<Double>] {
    let intersecting = excludedRanges.compactMap { range -> ClosedRange<Double>? in
      let lowerBound = max(range.lowerBound, 0)
      let upperBound = min(range.upperBound, 1)
      guard lowerBound <= upperBound else {
        return nil
      }
      return lowerBound...upperBound
    }
    .sorted {
      if $0.lowerBound != $1.lowerBound {
        return $0.lowerBound < $1.lowerBound
      }
      return $0.upperBound < $1.upperBound
    }

    return intersecting.reduce(into: []) { merged, range in
      guard let previous = merged.last,
        range.lowerBound <= previous.upperBound
      else {
        merged.append(range)
        return
      }

      merged[merged.count - 1] =
        (previous.lowerBound...max(previous.upperBound, range.upperBound))
    }
  }
}
