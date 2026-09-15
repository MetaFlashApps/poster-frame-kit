import CoreGraphics
import CoreMedia

/// The selected poster frame together with its score and measurements.
///
/// The conformance is unchecked because Core Graphics does not declare
/// immutable images as `Sendable`.
public struct PosterFrameResult: @unchecked Sendable {
    /// Display-oriented image selected by PosterFrameKit.
    public let image: CGImage

    /// Actual decoded timestamp of the selected frame.
    public let time: CMTime

    /// Normalized aggregate score in the range `0...1`.
    public let score: Double

    /// Measurements used to calculate ``score``.
    public let metrics: FrameMetrics

    /// Subtitle-aware score reduction applied during optional re-ranking.
    ///
    /// The value is zero when subtitle avoidance is disabled, no subtitle-like
    /// text is found, or the optional analysis fails.
    public let subtitlePenalty: Double

    /// Face-composition score increase applied during optional re-ranking.
    ///
    /// The value is zero when face preference is disabled, no eligible face is
    /// detected, or the optional analysis fails.
    public let faceCompositionBonus: Double

    /// Raw Apple Vision aesthetics score for the selected candidate.
    ///
    /// The value is in `-1...1`, or `nil` when aesthetic preference is
    /// disabled, unavailable, skipped, or fails.
    public let aestheticScore: Double?

    /// Whether Vision describes the selected candidate as useful but not
    /// necessarily memorable or exciting.
    public let isUtilityFrame: Bool?

    /// Signed change aligning the base score with optional Vision aesthetics.
    public let aestheticAdjustment: Double

    /// Score used by the final ranking after optional candidate refinements.
    public var adjustedScore: Double {
        min(
            max(
                score - subtitlePenalty + faceCompositionBonus
                    + aestheticAdjustment,
                0
            ),
            1
        )
    }

    /// Creates a poster-frame result.
    ///
    /// This initializer is useful for adapters and test doubles. Callers are
    /// responsible for supplying values that follow the documented ranges.
    ///
    /// - Parameters:
    ///   - image: Display-oriented selected image.
    ///   - time: Actual decoded timestamp of the selected frame.
    ///   - score: Normalized base score.
    ///   - metrics: Measurements used to calculate the base score.
    ///   - subtitlePenalty: Bounded subtitle-aware score reduction.
    ///   - faceCompositionBonus: Bounded face-composition score increase.
    ///   - aestheticScore: Optional raw Vision aesthetics score.
    ///   - isUtilityFrame: Optional Vision utility classification.
    ///   - aestheticAdjustment: Signed, bounded aesthetics adjustment.
    public init(
        image: CGImage,
        time: CMTime,
        score: Double,
        metrics: FrameMetrics,
        subtitlePenalty: Double = 0,
        faceCompositionBonus: Double = 0,
        aestheticScore: Double? = nil,
        isUtilityFrame: Bool? = nil,
        aestheticAdjustment: Double = 0
    ) {
        self.image = image
        self.time = time
        self.score = score
        self.metrics = metrics
        self.subtitlePenalty = subtitlePenalty
        self.faceCompositionBonus = faceCompositionBonus
        self.aestheticScore = aestheticScore
        self.isUtilityFrame = isUtilityFrame
        self.aestheticAdjustment = aestheticAdjustment
    }
}
