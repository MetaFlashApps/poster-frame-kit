import Foundation

/// Relative contributions of metrics to a custom poster-frame score.
///
/// ``PosterFrameOptions/normalized()`` scales all four values to a combined
/// total of `1`.
public struct PosterFrameWeights: Equatable, Sendable {
    /// Relative contribution from ``FrameMetrics/sharpness``.
    public var sharpness: Double

    /// Relative contribution from normalized luma deviation.
    public var contrast: Double

    /// Relative contribution from luma entropy trusted by coherent structure.
    public var entropy: Double

    /// Relative contribution from ``FrameMetrics/colorfulness``.
    public var colorfulness: Double

    /// Creates custom scoring weights.
    ///
    /// Relative values are accepted and normalized when the containing
    /// ``PosterFrameOptions`` value is normalized.
    ///
    /// - Parameters:
    ///   - sharpness: Relative contribution from edge sharpness.
    ///   - contrast: Relative contribution from luma contrast.
    ///   - entropy: Relative contribution from structure-qualified information density.
    ///   - colorfulness: Relative contribution from color variation.
    public init(
        sharpness: Double,
        contrast: Double,
        entropy: Double,
        colorfulness: Double
    ) {
        self.sharpness = sharpness
        self.contrast = contrast
        self.entropy = entropy
        self.colorfulness = colorfulness
    }

    func normalized() throws -> PosterFrameWeights {
        let weights = [
            sharpness,
            contrast,
            entropy,
            colorfulness,
        ]

        guard weights.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw PosterFrameError.invalidOptions(
                "custom profile weights must be finite and nonnegative"
            )
        }

        guard let largestWeight = weights.max(), largestWeight > 0 else {
            throw PosterFrameError.invalidOptions(
                "custom profile weights must contain a positive value"
            )
        }

        let total = weights.reduce(0, +)
        let normalizedTolerance = 8 * Double.ulpOfOne
        if total.isFinite, abs(total - 1) <= normalizedTolerance {
            return self
        }

        let scaledTotal = weights.reduce(0) { partialResult, weight in
            partialResult + (weight / largestWeight)
        }

        func normalizedWeight(_ weight: Double) -> Double {
            (weight / largestWeight) / scaledTotal
        }

        return PosterFrameWeights(
            sharpness: normalizedWeight(sharpness),
            contrast: normalizedWeight(contrast),
            entropy: normalizedWeight(entropy),
            colorfulness: normalizedWeight(colorfulness)
        )
    }
}
