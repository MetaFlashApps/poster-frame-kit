import CoreGraphics
import CoreImage
import CoreMedia
import CoreText
import Foundation
import ImageIO
import PosterFrameKit

enum FaceCalibrationRunner {
    private struct PassResult {
        let bounds: [CGRect]
        let confidences: [Float]
        let milliseconds: Double
    }

    private struct Candidate {
        let sample: PosterFrameSample
        let baseScore: Double
        let firstPass: PassResult
        let warmPass: PassResult

        var compositionQuality: Double {
            FaceCompositionScorer.quality(
                for: warmPass.bounds,
                confidences: warmPass.confidences
            )
        }
    }

    static func run(
        samples: [PosterFrameSample],
        profile: PosterFrameProfile,
        fixtureID: String,
        outputDirectory: URL
    ) async throws -> QualityReport.FaceCalibration {
        let analyzer = VisionFaceAnalyzer()
        let firstPassStart = ContinuousClock.now
        let firstPass = try await analyze(samples, with: analyzer)
        let firstPassDuration = firstPassStart.duration(to: .now)

        let warmPassStart = ContinuousClock.now
        let warmPass = try await analyze(samples, with: analyzer)
        let warmPassDuration = warmPassStart.duration(to: .now)

        let candidates = try zip(samples.indices, samples).map { index, sample in
            Candidate(
                sample: sample,
                baseScore: try PosterFrameKit.evaluate(
                    pixelBuffer: sample.pixelBuffer,
                    profile: profile
                ).score,
                firstPass: firstPass[index],
                warmPass: warmPass[index]
            )
        }
        let rankedIndices = candidates.indices.sorted {
            isPreferredByBaseScore(candidates[$0], over: candidates[$1])
        }
        guard let baseWinnerIndex = rankedIndices.first else {
            throw QualityBenchmarkError.noCandidates
        }

        let options = PosterFrameFaceOptions()
        let eligibleIndices = rankedIndices.prefix(options.candidateCount)
        guard let preferredWinnerIndex = eligibleIndices.max(by: { left, right in
            isFaceAdjustedCandidate(
                candidates[right],
                preferredOver: candidates[left],
                maximumBonus: options.maximumBonus
            )
        }) else {
            throw QualityBenchmarkError.noCandidates
        }

        let ranks = Dictionary(
            uniqueKeysWithValues: rankedIndices.enumerated().map {
                ($0.element, $0.offset + 1)
            }
        )
        let chronologicalIndices = candidates.indices.sorted {
            CMTimeCompare(
                candidates[$0].sample.actualTime,
                candidates[$1].sample.actualTime
            ) < 0
        }
        let fixtureDirectory = outputDirectory.appending(path: fixtureID)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        let contactSheetURL = fixtureDirectory.appending(
            path: "face-calibration.jpg"
        )
        try writeContactSheet(
            candidates: chronologicalIndices.map { candidates[$0] },
            ranks: chronologicalIndices.map { ranks[$0] ?? 0 },
            to: contactSheetURL
        )

        let candidateReports = candidates.indices.map { index in
            let candidate = candidates[index]
            return QualityReport.FaceCandidate(
                baseRank: ranks[index] ?? 0,
                timeSeconds: candidate.sample.actualTime.seconds,
                baseScore: candidate.baseScore,
                faceCount: candidate.warmPass.bounds.count,
                compositionQuality: candidate.compositionQuality,
                firstPassMilliseconds: candidate.firstPass.milliseconds,
                warmPassMilliseconds: candidate.warmPass.milliseconds,
                faceBounds: candidate.warmPass.bounds.map {
                    QualityReport.NormalizedBounds(
                        x: Double($0.origin.x),
                        y: Double($0.origin.y),
                        width: Double($0.width),
                        height: Double($0.height)
                    )
                },
                faceConfidences: candidate.warmPass.confidences
            )
        }

        return QualityReport.FaceCalibration(
            firstPassMilliseconds: firstPassDuration.qualityMilliseconds,
            warmPassMilliseconds: warmPassDuration.qualityMilliseconds,
            detectedCandidateCount: candidates.count {
                !$0.warmPass.bounds.isEmpty
            },
            scoredCandidateCount: candidates.count {
                $0.compositionQuality > 0
            },
            totalFaceCount: candidates.reduce(0) {
                $0 + $1.warmPass.bounds.count
            },
            detectionsStable: zip(firstPass, warmPass).allSatisfy {
                detectionsMatch($0, $1)
            },
            candidateCount: options.candidateCount,
            maximumBonus: options.maximumBonus,
            baseWinnerTimeSeconds: candidates[baseWinnerIndex]
                .sample.actualTime.seconds,
            preferredWinnerTimeSeconds: candidates[preferredWinnerIndex]
                .sample.actualTime.seconds,
            preferredWinnerCompositionQuality: candidates[
                preferredWinnerIndex
            ].compositionQuality,
            contactSheetPath: "\(fixtureID)/\(contactSheetURL.lastPathComponent)",
            candidates: candidateReports
        )
    }

    private static func analyze(
        _ samples: [PosterFrameSample],
        with analyzer: VisionFaceAnalyzer
    ) async throws -> [PassResult] {
        var results: [PassResult] = []
        results.reserveCapacity(samples.count)
        for sample in samples {
            try Task.checkCancellation()
            let start = ContinuousClock.now
            let analysis = try await analyzer.analyze(sample.pixelBuffer)
            results.append(
                PassResult(
                    bounds: analysis.faceBounds,
                    confidences: analysis.faceConfidences,
                    milliseconds: start.duration(to: .now).qualityMilliseconds
                )
            )
        }
        return results
    }

    private static func isPreferredByBaseScore(
        _ candidate: Candidate,
        over other: Candidate
    ) -> Bool {
        if candidate.baseScore != other.baseScore {
            return candidate.baseScore > other.baseScore
        }
        return CMTimeCompare(
            candidate.sample.actualTime,
            other.sample.actualTime
        ) < 0
    }

    private static func isFaceAdjustedCandidate(
        _ candidate: Candidate,
        preferredOver other: Candidate,
        maximumBonus: Double
    ) -> Bool {
        let score = min(
            candidate.baseScore + candidate.compositionQuality * maximumBonus,
            1
        )
        let otherScore = min(
            other.baseScore + other.compositionQuality * maximumBonus,
            1
        )
        if score != otherScore {
            return score > otherScore
        }
        return CMTimeCompare(
            candidate.sample.actualTime,
            other.sample.actualTime
        ) < 0
    }

    private static func detectionsMatch(
        _ first: PassResult,
        _ second: PassResult
    ) -> Bool {
        guard first.bounds.count == second.bounds.count else {
            return false
        }
        return zip(first.bounds, second.bounds).allSatisfy { left, right in
            abs(left.origin.x - right.origin.x) < 0.000_001
                && abs(left.origin.y - right.origin.y) < 0.000_001
                && abs(left.width - right.width) < 0.000_001
                && abs(left.height - right.height) < 0.000_001
        } && first.confidences == second.confidences
    }

    private static func writeContactSheet(
        candidates: [Candidate],
        ranks: [Int],
        to url: URL
    ) throws {
        let columns = 4
        let imageWidth = 320
        let imageHeight = 180
        let labelHeight = 34
        let rows = Int(ceil(Double(candidates.count) / Double(columns)))
        let width = columns * imageWidth
        let height = max(rows * (imageHeight + labelHeight), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw QualityBenchmarkError.imageCreationFailed
        }
        context.setFillColor(CGColor(gray: 0.08, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let imageContext = CIContext(options: [.cacheIntermediates: false])
        for (index, candidate) in candidates.enumerated() {
            let column = index % columns
            let row = index / columns
            let imageX = column * imageWidth
            let imageY = height - (row + 1) * (imageHeight + labelHeight)
                + labelHeight
            let imageRect = CGRect(
                x: imageX,
                y: imageY,
                width: imageWidth,
                height: imageHeight
            )
            let image = CIImage(cvPixelBuffer: candidate.sample.pixelBuffer)
            guard let cgImage = imageContext.createCGImage(
                image,
                from: image.extent
            ) else {
                throw QualityBenchmarkError.imageCreationFailed
            }
            context.draw(cgImage, in: imageRect)

            context.setStrokeColor(CGColor(red: 1, green: 0.24, blue: 0.18, alpha: 1))
            context.setLineWidth(3)
            for face in candidate.warmPass.bounds {
                context.stroke(
                    CGRect(
                        x: imageRect.minX + face.minX * imageRect.width,
                        y: imageRect.minY + face.minY * imageRect.height,
                        width: face.width * imageRect.width,
                        height: face.height * imageRect.height
                    )
                )
            }

            drawLabel(
                String(
                    format: "R%02d  %06.1fs  F%d  Q%.2f",
                    ranks[index],
                    candidate.sample.actualTime.seconds,
                    candidate.warmPass.bounds.count,
                    candidate.compositionQuality
                ),
                at: CGPoint(x: imageX + 7, y: imageY - 24),
                in: context
            )
        }

        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                "public.jpeg" as CFString,
                1,
                nil
            )
        else {
            throw QualityBenchmarkError.imageCreationFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [
                kCGImageDestinationLossyCompressionQuality as String: 0.82
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw QualityBenchmarkError.imageCreationFailed
        }
    }

    private static func drawLabel(
        _ text: String,
        at point: CGPoint,
        in context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String):
                CTFontCreateWithName("Menlo" as CFString, 16, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 0.96, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        context.textPosition = point
        CTLineDraw(line, context)
    }
}
