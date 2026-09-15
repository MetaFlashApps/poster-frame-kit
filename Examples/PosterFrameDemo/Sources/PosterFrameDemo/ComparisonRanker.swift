import CoreMedia

enum ComparisonRanker {
    static func bestVisionIndex(in scores: [VisionCandidateScore]) -> Int? {
        bestIndex(in: scores) { $0.visionScore }
    }

    static func bestHybridIndex(in scores: [VisionCandidateScore]) -> Int? {
        bestIndex(in: scores) { score in
            let normalizedVisionScore = min(max((score.visionScore + 1) / 2, 0), 1)
            return (normalizedVisionScore + score.posterFrameScore) / 2
        }
    }

    static func hybridScore(for score: VisionCandidateScore) -> Double {
        let normalizedVisionScore = min(max((score.visionScore + 1) / 2, 0), 1)
        return (normalizedVisionScore + score.posterFrameScore) / 2
    }

    private static func bestIndex(
        in scores: [VisionCandidateScore],
        value: (VisionCandidateScore) -> Double
    ) -> Int? {
        scores.indices.max { lhs, rhs in
            let lhsValue = value(scores[lhs])
            let rhsValue = value(scores[rhs])
            if lhsValue != rhsValue {
                return lhsValue < rhsValue
            }
            return CMTimeCompare(scores[lhs].time, scores[rhs].time) > 0
        }
    }
}
