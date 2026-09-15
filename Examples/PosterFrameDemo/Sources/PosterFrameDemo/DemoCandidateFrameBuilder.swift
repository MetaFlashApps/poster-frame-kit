import CoreGraphics
import CoreImage
import CoreVideo
import PosterFrameKit

enum DemoCandidateFrameBuilder {
    private static let maximumThumbnailSize = CGSize(width: 360, height: 203)

    static func make(
        samples: [PosterFrameSample],
        profile: PosterFrameProfile,
        recordedScores: [VisionCandidateScore]? = nil
    ) async throws -> [DemoCandidateFrame] {
        let task = Task.detached(priority: .userInitiated) {
            try build(
                samples: samples,
                profile: profile,
                recordedScores: recordedScores
            )
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func build(
        samples: [PosterFrameSample],
        profile: PosterFrameProfile,
        recordedScores: [VisionCandidateScore]?
    ) throws -> [DemoCandidateFrame] {
        let context = CIContext(options: [.cacheIntermediates: false])
        return try samples.enumerated().map { index, sample in
            try Task.checkCancellation()
            let recordedScore = recordedScores.flatMap { scores in
                scores.indices.contains(index) ? scores[index] : nil
            }
            let evaluation: (score: Double, metrics: FrameMetrics)
            if let recordedScore, let metrics = recordedScore.metrics {
                evaluation = (recordedScore.posterFrameScore, metrics)
            } else {
                evaluation = try PosterFrameKit.evaluate(
                    pixelBuffer: sample.pixelBuffer,
                    profile: profile
                )
            }
            return DemoCandidateFrame(
                id: index,
                thumbnail: try thumbnail(
                    from: sample.pixelBuffer,
                    context: context
                ),
                time: sample.actualTime,
                baseScore: evaluation.score,
                metrics: evaluation.metrics
            )
        }
    }

    private static func thumbnail(
        from pixelBuffer: CVPixelBuffer,
        context: CIContext
    ) throws -> CGImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = min(
            maximumThumbnailSize.width / image.extent.width,
            maximumThumbnailSize.height / image.extent.height,
            1
        )
        let scaledImage = image.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        guard let thumbnail = context.createCGImage(
            scaledImage,
            from: scaledImage.extent
        ) else {
            throw PosterFrameError.imageCreationFailed
        }
        return thumbnail
    }
}
