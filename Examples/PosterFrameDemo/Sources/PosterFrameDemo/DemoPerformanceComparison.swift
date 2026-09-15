import Foundation

struct DemoPerformanceComparison: Sendable {
    let posterFrameDuration: Duration
    let candidateCaptureDuration: Duration
    let visionRankingDuration: Duration

    init?(
        posterFrameDuration: Duration,
        candidateCaptureDuration: Duration,
        visionRankingDuration: Duration
    ) {
        let durations = [
            posterFrameDuration,
            candidateCaptureDuration,
            visionRankingDuration,
        ]
        guard durations.allSatisfy({ Self.seconds(in: $0) > 0 }) else {
            return nil
        }

        self.posterFrameDuration = posterFrameDuration
        self.candidateCaptureDuration = candidateCaptureDuration
        self.visionRankingDuration = visionRankingDuration
    }

    var visionPipelineDuration: Duration {
        candidateCaptureDuration + visionRankingDuration
    }

    var posterFrameSeconds: Double {
        Self.seconds(in: posterFrameDuration)
    }

    var visionPipelineSeconds: Double {
        Self.seconds(in: visionPipelineDuration)
    }

    var maximumSeconds: Double {
        max(posterFrameSeconds, visionPipelineSeconds)
    }

    var winner: DemoPerformanceWinner {
        let relativeDifference = abs(
            posterFrameSeconds - visionPipelineSeconds
        ) / maximumSeconds
        if relativeDifference <= 0.01 {
            return .tie
        }
        return posterFrameSeconds < visionPipelineSeconds
            ? .posterFrameKit
            : .visionPipeline
    }

    var speedupFactor: Double {
        maximumSeconds / min(posterFrameSeconds, visionPipelineSeconds)
    }

    var timeSavedFraction: Double {
        (maximumSeconds - min(posterFrameSeconds, visionPipelineSeconds))
            / maximumSeconds
    }

    private static func seconds(in duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
