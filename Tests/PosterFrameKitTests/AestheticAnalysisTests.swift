import CoreMedia
import XCTest

@testable import PosterFrameKit

final class AestheticAnalysisTests: XCTestCase {
    func testAestheticRerankerAppliesSignedBoundedAdjustment() async throws {
        let candidates = try candidates(scores: [0.80, 0.79])
        let analyzer = StubAestheticAnalyzer(
            results: [
                .success(AestheticAnalysis(score: -2, isUtilityFrame: true)),
                .success(AestheticAnalysis(score: 2, isUtilityFrame: false)),
            ]
        )

        let ranked = try await AestheticCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameAestheticOptions(
                candidateCount: 2,
                maximumAdjustment: 0.05
            ),
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: false)

        XCTAssertEqual(ranked.first?.candidate.time.seconds, 2)
        XCTAssertEqual(ranked.first?.aestheticScore, 1)
        XCTAssertEqual(ranked.first?.aestheticAdjustment, 0.05)
        XCTAssertEqual(ranked.first?.isUtilityFrame, false)
        XCTAssertEqual(ranked.last?.aestheticScore, -1)
        XCTAssertEqual(ranked.last?.aestheticAdjustment, -0.05)
        XCTAssertEqual(ranked.last?.isUtilityFrame, true)
        XCTAssertEqual(analyzer.callCount, 2)
    }

    func testAestheticRerankerStopsWhenMaximumAdjustmentCannotChangeWinner() async throws {
        let candidates = try candidates(scores: [0.80, 0.69, 0.60])
        let analyzer = StubAestheticAnalyzer(
            results: [
                .success(AestheticAnalysis(score: 1, isUtilityFrame: false))
            ]
        )

        let ranked = try await AestheticCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameAestheticOptions(
                candidateCount: 3,
                maximumAdjustment: 0.05
            ),
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: false)

        XCTAssertEqual(ranked.map(\.candidate.time.seconds), [1, 2, 3])
        let winner = try XCTUnwrap(ranked.first)
        XCTAssertEqual(winner.adjustedScore, 0.85, accuracy: 1e-12)
        XCTAssertNil(ranked[1].aestheticScore)
        XCTAssertEqual(analyzer.callCount, 1)
    }

    func testAnalyzeAllInspectsConfiguredCandidateGroup() async throws {
        let candidates = try candidates(scores: [0.80, 0.69, 0.60])
        let analyzer = StubAestheticAnalyzer(results: [])

        _ = try await AestheticCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameAestheticOptions(candidateCount: 3),
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: true)

        XCTAssertEqual(analyzer.callCount, 3)
    }

    func testVisionFirstAlignmentPreservesEarlierRefinements() async throws {
        var candidate = try XCTUnwrap(candidates(scores: [0.80]).first)
        candidate.faceCompositionBonus = 0.04
        candidate.subtitlePenalty = 0.02
        let analyzer = StubAestheticAnalyzer(
            results: [
                .success(AestheticAnalysis(score: -0.2, isUtilityFrame: false))
            ]
        )

        let ranked = try await AestheticCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameAestheticOptions(),
            performanceRecorder: nil
        ).rank([candidate], analyzeAll: false)

        let winner = try XCTUnwrap(ranked.first)
        XCTAssertEqual(winner.aestheticAdjustment, -0.4, accuracy: 1e-12)
        XCTAssertEqual(winner.adjustedScore, 0.42, accuracy: 1e-12)
        XCTAssertEqual(winner.faceCompositionBonus, 0.04)
        XCTAssertEqual(winner.subtitlePenalty, 0.02)
    }

    func testVisionAestheticAnalyzerReturnsDocumentedValues() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *) else {
            throw XCTSkip("Vision image aesthetics is unavailable.")
        }
        let pixelBuffer = try TestPixelBufferFactory.bgra(
            width: 320,
            height: 180
        ) { x, y in
            let red = UInt8(x * 255 / 319)
            let green = UInt8(y * 255 / 179)
            return (blue: 96, green: green, red: red)
        }

        let analysis = try await VisionAestheticAnalyzer().analyze(pixelBuffer)

        XCTAssertTrue((-1...1).contains(analysis.score))
    }

    private func candidates(scores: [Double]) throws -> [RefinedCandidate] {
        let pixelBuffer = try TestPixelBufferFactory.monochrome(
            width: 16,
            height: 16
        ) { _, _ in 128 }
        let metrics = FrameMetrics(
            meanLuma: 0,
            lumaDeviation: 0,
            entropy: 0,
            sharpness: 0,
            colorfulness: 0,
            visualNoise: 0
        )
        return scores.enumerated().map { index, score in
            RefinedCandidate(
                candidate: EvaluatedCandidate(
                    pixelBuffer: pixelBuffer,
                    time: CMTime(
                        seconds: Double(index + 1),
                        preferredTimescale: 600
                    ),
                    score: score,
                    metrics: metrics
                )
            )
        }
    }
}
