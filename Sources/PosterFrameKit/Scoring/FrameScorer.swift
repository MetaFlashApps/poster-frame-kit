import Foundation

struct FrameScorer {
    static func score(
        metrics: FrameMetrics,
        profile: PosterFrameProfile
    ) -> Double {
        let weights = ProfileWeights.weights(for: profile)
        let contrast = min(max(metrics.lumaDeviation * 2, 0), 1)
        let entropy = structuredEntropy(metrics)
        let weightedScore = metrics.sharpness * weights.sharpness
            + contrast * weights.contrast
            + entropy * weights.entropy
            + metrics.colorfulness * weights.colorfulness

        let darkExposure = metrics.meanLuma / 0.12
        let lightExposure = (1 - metrics.meanLuma) / 0.12
        let exposure = min(max(min(darkExposure, lightExposure), 0), 1)
        let detail = min(
            max(contrast + entropy + metrics.sharpness, 0) / 0.35,
            1
        )
        let contentFactor = 0.25 + 0.75 * detail
        let visualNoiseFactor = 1 - (0.25 * metrics.visualNoise)

        return min(
            max(weightedScore * exposure * contentFactor * visualNoiseFactor, 0),
            1
        )
    }

    private static func structuredEntropy(_ metrics: FrameMetrics) -> Double {
        // Global histogram entropy can be high for a perfectly smooth luma
        // ramp even though the frame contains almost no spatial structure.
        // Preserve modest tonal diversity without edges, then restore the raw
        // entropy contribution once coherent Tenengrad structure reaches the
        // range produced by ordinary image edges. Dense visual noise must not
        // legitimize its own inflated entropy through sharpness.
        let coherentSharpness = metrics.sharpness * (1 - metrics.visualNoise)
        let lowerStructureBound = 0.01
        let upperStructureBound = 0.04
        let normalizedStructure = min(
            max(
                (coherentSharpness - lowerStructureBound)
                    / (upperStructureBound - lowerStructureBound),
                0
            ),
            1
        )
        let structureConfidence = normalizedStructure * normalizedStructure
            * (3 - 2 * normalizedStructure)
        let trustedEntropyLimit = 0.20 + 0.80 * structureConfidence
        return min(metrics.entropy, trustedEntropyLimit)
    }
}
