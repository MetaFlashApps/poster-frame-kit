import Foundation
import PosterFrameKit

enum DemoAnalysisCoordinator {
    static func run(
        videoURL: URL,
        options: PosterFrameOptions,
        comparisonCaptureOptions: PosterFrameOptions,
        progress: @escaping @MainActor @Sendable (DemoAnalysisProgress) -> Void
    ) async throws -> DemoAnalysisOutput {
        let selectionStart = ContinuousClock.now
        let selection = try await PosterFrameKit.bestFrame(
            in: videoURL,
            options: options
        )
        try Task.checkCancellation()
        await progress(
            .selected(
                selection,
                duration: selectionStart.duration(to: .now)
            )
        )

        do {
            return try await captureComparison(
                videoURL: videoURL,
                options: options,
                captureOptions: comparisonCaptureOptions,
                progress: progress
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch PosterFrameError.cancelled {
            throw PosterFrameError.cancelled
        } catch let failure as ComparisonFailure {
            return DemoAnalysisOutput(
                comparisonCaptureDuration: nil,
                visionDuration: nil,
                candidateFrames: [],
                visionResult: nil,
                hybridResult: nil,
                comparisonErrorMessage: failure.message
            )
        }
    }

    private static func captureComparison(
        videoURL: URL,
        options: PosterFrameOptions,
        captureOptions: PosterFrameOptions,
        progress: @escaping @MainActor @Sendable (DemoAnalysisProgress) -> Void
    ) async throws -> DemoAnalysisOutput {
        await progress(.stage(.comparisonCapture))
        let source = CandidateRecordingFrameSource(url: videoURL)
        let captureStart = ContinuousClock.now
        do {
            _ = try await PosterFrameKit.bestFrame(
                from: source,
                options: captureOptions
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch PosterFrameError.cancelled {
            throw PosterFrameError.cancelled
        } catch {
            throw ComparisonFailure(
                message: "Candidate capture failed: \(error.localizedDescription)"
            )
        }
        try Task.checkCancellation()
        let captureDuration = captureStart.duration(to: .now)
        let samples = await source.samples()
        guard !samples.isEmpty else {
            throw ComparisonFailure(
                message: "Candidate capture failed: "
                    + PosterFrameError.noCandidateFrames.localizedDescription
            )
        }

        if #available(macOS 15.0, *) {
            await progress(.stage(.vision))
            do {
                let visionStart = ContinuousClock.now
                let comparison = try await VisionComparisonRunner.run(
                    samples: samples,
                    profile: options.profile
                )
                let visionDuration = visionStart.duration(to: .now)
                let frames = try await DemoCandidateFrameBuilder.make(
                    samples: samples,
                    profile: options.profile,
                    recordedScores: comparison.candidateScores
                )
                try Task.checkCancellation()
                return DemoAnalysisOutput(
                    comparisonCaptureDuration: captureDuration,
                    visionDuration: visionDuration,
                    candidateFrames: frames,
                    visionResult: comparison.vision,
                    hybridResult: comparison.hybrid,
                    comparisonErrorMessage: nil
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch PosterFrameError.cancelled {
                throw PosterFrameError.cancelled
            } catch {
                throw ComparisonFailure(message: error.localizedDescription)
            }
        }

        do {
            let frames = try await DemoCandidateFrameBuilder.make(
                samples: samples,
                profile: options.profile
            )
            try Task.checkCancellation()
            return DemoAnalysisOutput(
                comparisonCaptureDuration: captureDuration,
                visionDuration: nil,
                candidateFrames: frames,
                visionResult: nil,
                hybridResult: nil,
                comparisonErrorMessage: nil
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch PosterFrameError.cancelled {
            throw PosterFrameError.cancelled
        } catch {
            throw ComparisonFailure(message: error.localizedDescription)
        }
    }

    private struct ComparisonFailure: Error {
        let message: String
    }
}
