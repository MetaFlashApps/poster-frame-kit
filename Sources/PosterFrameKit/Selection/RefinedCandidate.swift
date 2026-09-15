import CoreMedia

struct RefinedCandidate: Sendable {
    let candidate: EvaluatedCandidate
    var subtitlePenalty: Double
    var faceCompositionBonus: Double
    var aestheticScore: Double?
    var isUtilityFrame: Bool?
    var aestheticAdjustment: Double

    init(
        candidate: EvaluatedCandidate,
        subtitlePenalty: Double = 0,
        faceCompositionBonus: Double = 0,
        aestheticScore: Double? = nil,
        isUtilityFrame: Bool? = nil,
        aestheticAdjustment: Double = 0
    ) {
        self.candidate = candidate
        self.subtitlePenalty = subtitlePenalty
        self.faceCompositionBonus = faceCompositionBonus
        self.aestheticScore = aestheticScore
        self.isUtilityFrame = isUtilityFrame
        self.aestheticAdjustment = aestheticAdjustment
    }

    var scoreBeforeSubtitlePenalty: Double {
        candidate.score + faceCompositionBonus
    }

    var adjustedScore: Double {
        min(
            max(
                scoreBeforeSubtitlePenalty - subtitlePenalty
                    + aestheticAdjustment,
                0
            ),
            1
        )
    }

    func isPreferred(over other: RefinedCandidate) -> Bool {
        if adjustedScore != other.adjustedScore {
            return adjustedScore > other.adjustedScore
        }
        return CMTimeCompare(candidate.time, other.candidate.time) < 0
    }
}
