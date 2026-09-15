import CoreImage
import PosterFrameKit
import Vision

enum VisionComparisonRunner {
    @available(macOS 15.0, *)
    static func run(
        samples: [PosterFrameSample],
        profile: PosterFrameProfile
    ) async throws -> VisionComparison {
        var scores: [VisionCandidateScore] = []
        scores.reserveCapacity(samples.count)
        let request = CalculateImageAestheticsScoresRequest()

        for sample in samples {
            try Task.checkCancellation()
            let observation = try await request.perform(on: sample.pixelBuffer)
            let evaluation = try PosterFrameKit.evaluate(
                pixelBuffer: sample.pixelBuffer,
                profile: profile
            )
            scores.append(
                VisionCandidateScore(
                    time: sample.actualTime,
                    visionScore: Double(observation.overallScore),
                    posterFrameScore: evaluation.score,
                    isUtility: observation.isUtility,
                    metrics: evaluation.metrics
                )
            )
        }

        guard let visionIndex = ComparisonRanker.bestVisionIndex(in: scores),
              let hybridIndex = ComparisonRanker.bestHybridIndex(in: scores)
        else {
            throw PosterFrameError.noCandidateFrames
        }

        let context = CIContext(options: [.cacheIntermediates: false])
        let visionScore = scores[visionIndex]
        let hybridScore = scores[hybridIndex]
        return VisionComparison(
            vision: try result(
                sample: samples[visionIndex],
                score: visionScore.visionScore,
                isUtility: visionScore.isUtility,
                context: context
            ),
            hybrid: try result(
                sample: samples[hybridIndex],
                score: ComparisonRanker.hybridScore(for: hybridScore),
                isUtility: hybridScore.isUtility,
                context: context
            ),
            candidateScores: scores
        )
    }

    private static func result(
        sample: PosterFrameSample,
        score: Double,
        isUtility: Bool,
        context: CIContext
    ) throws -> DemoComparisonResult {
        let image = CIImage(cvPixelBuffer: sample.pixelBuffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw PosterFrameError.imageCreationFailed
        }
        return DemoComparisonResult(
            image: cgImage,
            time: sample.actualTime,
            score: score,
            isUtility: isUtility
        )
    }
}
