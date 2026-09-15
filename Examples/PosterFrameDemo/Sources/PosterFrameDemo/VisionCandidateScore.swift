import CoreMedia
import PosterFrameKit

struct VisionCandidateScore: Sendable {
    let time: CMTime
    let visionScore: Double
    let posterFrameScore: Double
    let isUtility: Bool
    let metrics: FrameMetrics?

    init(
        time: CMTime,
        visionScore: Double,
        posterFrameScore: Double,
        isUtility: Bool,
        metrics: FrameMetrics? = nil
    ) {
        self.time = time
        self.visionScore = visionScore
        self.posterFrameScore = posterFrameScore
        self.isUtility = isUtility
        self.metrics = metrics
    }
}
