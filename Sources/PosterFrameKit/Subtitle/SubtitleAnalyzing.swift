import CoreGraphics
import CoreVideo

package protocol SubtitleAnalyzing: Sendable {
    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> SubtitleAnalysis
}

package struct SubtitleAnalysis: Equatable, Sendable {
    package let likelihood: Double
    package let usedAccurateRecognition: Bool

    package static let none = SubtitleAnalysis(
        likelihood: 0,
        usedAccurateRecognition: false
    )
}

enum SubtitleRegionScorer {
    static func likelihood(for regions: [CGRect]) -> Double {
        let eligible = regions.filter(isSubtitleLike)
        guard !eligible.isEmpty else {
            return 0
        }

        let totalWidth = eligible.reduce(0.0) { $0 + Double($1.width) }
        let weightedCenter = eligible.reduce(0.0) {
            $0 + Double($1.midX * $1.width)
        } / max(totalWidth, .leastNonzeroMagnitude)
        let weightedVerticalCenter = eligible.reduce(0.0) {
            $0 + Double($1.midY * $1.width)
        } / max(totalWidth, .leastNonzeroMagnitude)

        let coverage = min(totalWidth / 0.75, 1)
        let countFactor = min(Double(eligible.count) / 3, 1)
        let centrality = 1 - min(abs(weightedCenter - 0.5) / 0.5, 1)
        let lowerPlacement = 1 - min(max((weightedVerticalCenter - 0.45) / 0.55, 0), 1)

        return min(
            max(
                0.15
                    + 0.35 * coverage
                    + 0.15 * countFactor
                    + 0.20 * centrality
                    + 0.15 * lowerPlacement,
                0
            ),
            1
        )
    }

    private static func isSubtitleLike(_ region: CGRect) -> Bool {
        region.width.isFinite
            && region.height.isFinite
            && region.width > 0
            && region.height >= 0.04
            && region.height <= 0.50
            && region.midX >= 0.08
            && region.midX <= 0.92
            && region.minY < 0.80
    }
}

func makeSubtitleAnalyzer() -> any SubtitleAnalyzing {
    VisionSubtitleAnalyzer()
}
