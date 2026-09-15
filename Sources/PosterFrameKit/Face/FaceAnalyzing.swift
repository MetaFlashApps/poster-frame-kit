import CoreGraphics
import CoreVideo

protocol FaceAnalyzing: Sendable {
    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> FaceAnalysis
}

package struct FaceAnalysis: Equatable, Sendable {
    package let faceBounds: [CGRect]
    package let faceConfidences: [Float]

    package init(
        faceBounds: [CGRect],
        faceConfidences: [Float]? = nil
    ) {
        self.faceBounds = faceBounds
        if let faceConfidences,
            faceConfidences.count == faceBounds.count
        {
            self.faceConfidences = faceConfidences
        } else {
            self.faceConfidences = Array(
                repeating: 1,
                count: faceBounds.count
            )
        }
    }

    package static let none = FaceAnalysis(faceBounds: [])
}

package enum FaceCompositionScorer {
    private static let minimumConfidence: Float = 0.70

    package static func quality(
        for faceBounds: [CGRect],
        confidences: [Float]? = nil
    ) -> Double {
        let confidences = normalizedConfidences(
            confidences,
            count: faceBounds.count
        )
        let scores: [(quality: Double, confidence: Double)] = zip(
            faceBounds,
            confidences
        ).compactMap { bounds, confidence in
            guard confidence >= minimumConfidence else {
                return nil
            }
            let confidence = Double(confidence)
            return individualScore(for: bounds).map {
                (quality: $0 * confidence, confidence: confidence)
            }
        }
        guard let bestIndex = scores.indices.max(by: {
            scores[$0].quality < scores[$1].quality
        }) else {
            return 0
        }

        let groupBonus = min(
            scores.indices
                .filter { $0 != bestIndex }
                .reduce(0) { $0 + scores[$1].confidence * 0.08 },
            0.16
        )
        return min(scores[bestIndex].quality + groupBonus, 1)
    }

    private static func normalizedConfidences(
        _ confidences: [Float]?,
        count: Int
    ) -> [Float] {
        guard let confidences, confidences.count == count else {
            return Array(repeating: 1, count: count)
        }
        return confidences.map { min(max($0, 0), 1) }
    }

    private static func individualScore(for bounds: CGRect) -> Double? {
        guard bounds.origin.x.isFinite,
            bounds.origin.y.isFinite,
            bounds.width.isFinite,
            bounds.height.isFinite,
            bounds.width > 0,
            bounds.height > 0
        else {
            return nil
        }

        let visibleBounds = bounds.intersection(
            CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        guard !visibleBounds.isNull else {
            return nil
        }

        let area = Double(visibleBounds.width * visibleBounds.height)
        let sizeScore: Double
        switch area {
        case ...0.01:
            return nil
        case ..<0.08:
            sizeScore = (area - 0.01) / 0.07
        case ...0.35:
            sizeScore = 1
        case ..<0.65:
            sizeScore = (0.65 - area) / 0.30
        default:
            return nil
        }

        let horizontalDistance = abs(Double(visibleBounds.midX) - 0.5) / 0.5
        let verticalDistance = abs(Double(visibleBounds.midY) - 0.55) / 0.55
        let positionScore = max(
            1
                - sqrt(
                    horizontalDistance * horizontalDistance
                        + verticalDistance * verticalDistance
                ),
            0
        )

        return min(max(0.75 * sizeScore + 0.25 * positionScore, 0), 1)
    }
}

func makeFaceAnalyzer() -> any FaceAnalyzing {
    VisionFaceAnalyzer()
}
