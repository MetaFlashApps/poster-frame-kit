import CoreImage
import CoreMedia
import Foundation
import ImageIO
import PosterFrameKit
@preconcurrency import Vision

enum QualityComparisonRunner {
    enum QualityPosterFramePolicy: Equatable, Sendable {
        case deterministic
        case visionFirst
    }

    private struct Candidate {
        let sample: PosterFrameSample
        let posterFrameScore: Double
        let visionScore: Double
        let isUtilityFrame: Bool

        var hybridScore: Double {
            let normalizedVisionScore = min(max((visionScore + 1) / 2, 0), 1)
            return (posterFrameScore + normalizedVisionScore) / 2
        }
    }

    @available(macOS 15.0, *)
    static func run(
        fixture: QualityFixtureManifest.Fixture,
        videoURL: URL,
        candidateCount: Int,
        outputDirectory: URL,
        galleryDirectory: URL?,
        posterFramePolicy: QualityPosterFramePolicy = .visionFirst,
        profileOverride: QualityProfileOverride? = nil,
        includesFaceCalibration: Bool = false,
        aestheticCandidateCount: Int =
            PosterFrameAestheticOptions().candidateCount
    ) async throws -> QualityReport.FixtureResult {
        let source = RecordingFrameSource(url: videoURL)
        let profile = profileOverride?.profile ?? fixture.profile
        let options = PosterFrameOptions(
            maximumFramesExamined: candidateCount,
            excludedRanges: [0.46...0.54],
            profile: profile,
            facePreference: posterFramePolicy == .visionFirst
                ? PosterFrameFaceOptions()
                : nil,
            aestheticPreference: posterFramePolicy == .visionFirst
                ? PosterFrameAestheticOptions(
                    candidateCount: aestheticCandidateCount
                )
                : nil,
            outputSize: CGSize(width: 1_280, height: 720)
        )

        let captureStart = ContinuousClock.now
        let posterFrameResult = try await PosterFrameKit.bestFrame(
            from: source,
            options: options
        )
        let captureDuration = captureStart.duration(to: .now)
        let samples = await source.samples()
        guard !samples.isEmpty else {
            throw QualityBenchmarkError.noCandidates
        }
        let faceCalibration = includesFaceCalibration
            ? try await FaceCalibrationRunner.run(
                samples: samples,
                profile: profile,
                fixtureID: fixture.id,
                outputDirectory: outputDirectory
            )
            : nil

        let midpointSource = AVFoundationFrameSource(url: videoURL)
        let duration = try await midpointSource.duration
        let midpointSample = try await midpointSource.frame(
            at: CMTimeMultiplyByFloat64(duration, multiplier: 0.5),
            maximumSize: CGSize(width: 1_280, height: 720)
        )
        let midpointEvaluation = try PosterFrameKit.evaluate(
            pixelBuffer: midpointSample.pixelBuffer,
            profile: profile
        )

        let visionStart = ContinuousClock.now
        let request = CalculateImageAestheticsScoresRequest()
        var candidates: [Candidate] = []
        candidates.reserveCapacity(samples.count)
        for sample in samples {
            try Task.checkCancellation()
            let observation = try await request.perform(on: sample.pixelBuffer)
            let evaluation = try PosterFrameKit.evaluate(
                pixelBuffer: sample.pixelBuffer,
                profile: profile
            )
            candidates.append(
                Candidate(
                    sample: sample,
                    posterFrameScore: evaluation.score,
                    visionScore: Double(observation.overallScore),
                    isUtilityFrame: observation.isUtility
                )
            )
        }
        let visionDuration = visionStart.duration(to: .now)

        guard let visionWinner = best(in: candidates, score: \.visionScore),
            let hybridWinner = best(in: candidates, score: \.hybridScore)
        else {
            throw QualityBenchmarkError.noCandidates
        }

        let fixtureDirectory = outputDirectory.appending(path: fixture.id)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        let posterFrameURL = fixtureDirectory.appending(path: "posterframekit.png")
        let midpointURL = fixtureDirectory.appending(path: "midpoint.png")
        let visionURL = fixtureDirectory.appending(path: "vision.png")
        let hybridURL = fixtureDirectory.appending(path: "hybrid.png")
        try write(posterFrameResult.image, to: posterFrameURL)
        try write(midpointSample.pixelBuffer, to: midpointURL)
        try write(visionWinner.sample.pixelBuffer, to: visionURL)
        try write(hybridWinner.sample.pixelBuffer, to: hybridURL)

        if let galleryDirectory {
            let galleryFixtureDirectory = galleryDirectory.appending(
                path: fixture.id
            )
            try FileManager.default.createDirectory(
                at: galleryFixtureDirectory,
                withIntermediateDirectories: true
            )
            try writeJPEG(
                midpointSample.pixelBuffer,
                to: galleryFixtureDirectory.appending(path: "midpoint.jpg")
            )
            try writeJPEG(
                posterFrameResult.image,
                to: galleryFixtureDirectory.appending(path: "posterframekit.jpg")
            )
        }

        return QualityReport.FixtureResult(
            id: fixture.id,
            profile: profileOverride?.rawValue ?? fixture.expectations.profile,
            decodedCandidateCount: samples.count,
            captureMilliseconds: captureDuration.qualityMilliseconds,
            visionAnalysisMilliseconds: visionDuration.qualityMilliseconds,
            midpoint: selection(
                time: midpointSample.actualTime,
                adjustedScore: midpointEvaluation.score,
                posterFrameScore: midpointEvaluation.score,
                fixture: fixture,
                imageURL: midpointURL,
                faceCompositionBonus: 0,
                visionScore: nil,
                isUtilityFrame: nil
            ),
            posterFrameKit: selection(
                time: posterFrameResult.time,
                adjustedScore: posterFrameResult.adjustedScore,
                posterFrameScore: posterFrameResult.score,
                fixture: fixture,
                imageURL: posterFrameURL,
                faceCompositionBonus: posterFrameResult.faceCompositionBonus,
                visionScore: posterFrameResult.aestheticScore,
                isUtilityFrame: posterFrameResult.isUtilityFrame
            ),
            vision: selection(
                candidate: visionWinner,
                score: visionWinner.visionScore,
                fixture: fixture,
                imageURL: visionURL
            ),
            hybrid: selection(
                candidate: hybridWinner,
                score: hybridWinner.hybridScore,
                fixture: fixture,
                imageURL: hybridURL
            ),
            faceCalibration: faceCalibration
        )
    }

    private static func best(
        in candidates: [Candidate],
        score: KeyPath<Candidate, Double>
    ) -> Candidate? {
        candidates.max { lhs, rhs in
            let left = lhs[keyPath: score]
            let right = rhs[keyPath: score]
            if left != right {
                return left < right
            }
            return CMTimeCompare(lhs.sample.actualTime, rhs.sample.actualTime) > 0
        }
    }

    private static func selection(
        time: CMTime,
        adjustedScore: Double,
        posterFrameScore: Double,
        fixture: QualityFixtureManifest.Fixture,
        imageURL: URL,
        faceCompositionBonus: Double,
        visionScore: Double?,
        isUtilityFrame: Bool?
    ) -> QualityReport.Selection {
        QualityReport.Selection(
            timeSeconds: time.seconds,
            score: adjustedScore,
            acceptable: isAcceptable(time.seconds, for: fixture),
            imagePath: "\(fixture.id)/\(imageURL.lastPathComponent)",
            faceCompositionBonus: faceCompositionBonus,
            visionScore: visionScore,
            posterFrameScore: posterFrameScore,
            isUtilityFrame: isUtilityFrame
        )
    }

    private static func selection(
        candidate: Candidate,
        score: Double,
        fixture: QualityFixtureManifest.Fixture,
        imageURL: URL
    ) -> QualityReport.Selection {
        QualityReport.Selection(
            timeSeconds: candidate.sample.actualTime.seconds,
            score: score,
            acceptable: isAcceptable(
                candidate.sample.actualTime.seconds,
                for: fixture
            ),
            imagePath: "\(fixture.id)/\(imageURL.lastPathComponent)",
            faceCompositionBonus: nil,
            visionScore: candidate.visionScore,
            posterFrameScore: candidate.posterFrameScore,
            isUtilityFrame: candidate.isUtilityFrame
        )
    }

    private static func isAcceptable(
        _ time: Double,
        for fixture: QualityFixtureManifest.Fixture
    ) -> Bool? {
        guard !fixture.acceptableRanges.isEmpty else {
            return nil
        }
        return fixture.acceptableRanges.contains { $0.contains(time) }
    }

    private static func write(_ pixelBuffer: CVPixelBuffer, to url: URL) throws {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw QualityBenchmarkError.imageCreationFailed
        }
        try write(cgImage, to: url)
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        try write(
            image,
            to: url,
            typeIdentifier: "public.png" as CFString,
            properties: nil
        )
    }

    private static func writeJPEG(
        _ pixelBuffer: CVPixelBuffer,
        to url: URL
    ) throws {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw QualityBenchmarkError.imageCreationFailed
        }
        try writeJPEG(cgImage, to: url)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) throws {
        try write(
            image,
            to: url,
            typeIdentifier: "public.jpeg" as CFString,
            properties: [
                kCGImageDestinationLossyCompressionQuality as String: 0.8
            ] as CFDictionary
        )
    }

    private static func write(
        _ image: CGImage,
        to url: URL,
        typeIdentifier: CFString,
        properties: CFDictionary?
    ) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                typeIdentifier,
                1,
                nil
            )
        else {
            throw QualityBenchmarkError.imageCreationFailed
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw QualityBenchmarkError.imageCreationFailed
        }
    }
}
