import CoreGraphics
import CoreMedia
import CoreText
import CoreVideo
import XCTest

@testable import PosterFrameKit

final class SubtitleAnalysisTests: XCTestCase {
    func testRegionScorerIgnoresEmptyAndPeripheralRegions() {
        XCTAssertEqual(SubtitleRegionScorer.likelihood(for: []), 0)
        XCTAssertEqual(
            SubtitleRegionScorer.likelihood(
                for: [CGRect(x: 0.94, y: 0.1, width: 0.04, height: 0.2)]
            ),
            0
        )
    }

    func testRegionScorerRewardsCenteredMultiwordLine() {
        let singleWord = SubtitleRegionScorer.likelihood(
            for: [CGRect(x: 0.48, y: 0.15, width: 0.08, height: 0.15)]
        )
        let line = SubtitleRegionScorer.likelihood(
            for: [
                CGRect(x: 0.16, y: 0.15, width: 0.13, height: 0.19),
                CGRect(x: 0.35, y: 0.15, width: 0.09, height: 0.19),
                CGRect(x: 0.64, y: 0.15, width: 0.20, height: 0.19),
            ]
        )

        XCTAssertGreaterThan(singleWord, 0)
        XCTAssertGreaterThan(line, singleWord)
        XCTAssertLessThanOrEqual(line, 1)
    }

    func testBandHeuristicFindsConcentratedBottomTextPattern() throws {
        let buffer = try subtitlePattern(rows: 140..<158)
        var heuristic = SubtitleBandHeuristic()

        XCTAssertTrue(try heuristic.isSuspicious(buffer))
    }

    func testBandHeuristicIgnoresFlatAndUpperPatterns() throws {
        let flat = try TestPixelBufferFactory.monochrome(
            width: 320,
            height: 180
        ) { _, _ in 96 }
        let upperPattern = try subtitlePattern(rows: 24..<42)
        var heuristic = SubtitleBandHeuristic()

        XCTAssertFalse(try heuristic.isSuspicious(flat))
        XCTAssertFalse(try heuristic.isSuspicious(upperPattern))
    }

    func testBandHeuristicFindsSmallOutlinedTextOnBusyBackground() throws {
        let clean = try busyLowerThirdBuffer(includesText: false)
        let subtitle = try busyLowerThirdBuffer(includesText: true)
        var cleanHeuristic = SubtitleBandHeuristic()
        var subtitleHeuristic = SubtitleBandHeuristic()

        XCTAssertFalse(try cleanHeuristic.isSuspicious(clean))
        let diagnostics = try subtitleHeuristic.diagnostics(subtitle)
        XCTAssertTrue(diagnostics.isSuspicious, "\(diagnostics)")
        XCTAssertGreaterThanOrEqual(diagnostics.brightStrokeCount, 80)
        XCTAssertGreaterThanOrEqual(
            diagnostics.brightStrokeConcentration,
            0.33
        )
    }

    func testEarlyTerminationMatchesCompleteReferenceRanking() async throws {
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
        let candidates = [0.80, 0.79, 0.70].enumerated().map { index, score in
            RefinedCandidate(
                candidate: EvaluatedCandidate(
                    pixelBuffer: pixelBuffer,
                    time: CMTime(seconds: Double(index + 1), preferredTimescale: 600),
                    score: score,
                    metrics: metrics
                )
            )
        }
        let earlyAnalyzer = StubSubtitleAnalyzer(results: [.success(.none)])
        let completeAnalyzer = StubSubtitleAnalyzer(
            results: Array(repeating: .success(.none), count: 3)
        )
        let options = PosterFrameSubtitleOptions(
            candidateCount: 3,
            maximumPenalty: 0.08
        )

        let early = try await SubtitleCandidateReranker(
            analyzer: earlyAnalyzer,
            options: options,
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: false)
        let complete = try await SubtitleCandidateReranker(
            analyzer: completeAnalyzer,
            options: options,
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: true)

        XCTAssertEqual(early.first?.candidate.time, complete.first?.candidate.time)
        XCTAssertEqual(earlyAnalyzer.callCount, 1)
        XCTAssertEqual(completeAnalyzer.callCount, 3)
    }

    func testEarlyTerminationPreservesEarlierTimestampTieBreaker() async throws {
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
        let candidates = [
            RefinedCandidate(
                candidate: EvaluatedCandidate(
                    pixelBuffer: pixelBuffer,
                    time: CMTime(seconds: 10, preferredTimescale: 600),
                    score: 0.50,
                    metrics: metrics
                )
            ),
            RefinedCandidate(
                candidate: EvaluatedCandidate(
                    pixelBuffer: pixelBuffer,
                    time: CMTime(seconds: 5, preferredTimescale: 600),
                    score: 0.40,
                    metrics: metrics
                )
            ),
        ]
        let analyzer = StubSubtitleAnalyzer(
            results: [
                .success(
                    SubtitleAnalysis(
                        likelihood: 1,
                        usedAccurateRecognition: false
                    )
                ),
                .success(.none),
            ]
        )

        let ranked = try await SubtitleCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameSubtitleOptions(
                candidateCount: 2,
                maximumPenalty: 0.10
            ),
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: false)

        XCTAssertEqual(ranked.first?.candidate.time.seconds, 5)
        XCTAssertEqual(ranked.first?.adjustedScore, 0.40)
        XCTAssertEqual(analyzer.callCount, 2)
    }

    func testRerankerPreservesCandidatesOutsideItsInspectionGroup() async throws {
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
        let candidates = [0.80, 0.79, 0.78, 0.77].enumerated().map { index, score in
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
        let analyzer = StubSubtitleAnalyzer(
            results: Array(repeating: .success(.none), count: 2)
        )

        let ranked = try await SubtitleCandidateReranker(
            analyzer: analyzer,
            options: PosterFrameSubtitleOptions(candidateCount: 2),
            performanceRecorder: nil
        ).rank(candidates, analyzeAll: true)

        XCTAssertEqual(ranked.map(\.candidate.time.seconds), [1, 2, 3, 4])
        XCTAssertEqual(analyzer.callCount, 2)
    }

    func testVisionAnalyzerRecognizesGeneratedLowerThirdText() async throws {
        let pixelBuffer = try lowerThirdTextBuffer()

        let analysis = try await VisionSubtitleAnalyzer().analyze(pixelBuffer)

        XCTAssertGreaterThan(analysis.likelihood, 0)
    }

    private func subtitlePattern(rows: Range<Int>) throws -> CVPixelBuffer {
        try TestPixelBufferFactory.monochrome(width: 320, height: 180) { x, y in
            guard rows.contains(y), (40..<280).contains(x) else {
                return 72
            }
            let glyphX = (x - 40) % 14
            let glyphY = y - rows.lowerBound
            let isStroke =
                glyphX <= 2
                || glyphX >= 10
                || glyphY <= 2
                || glyphY >= rows.count - 3
            return isStroke ? 245 : 18
        }
    }

    private func lowerThirdTextBuffer() throws -> CVPixelBuffer {
        let width = 640
        let height = 360
        let pixelBuffer = try TestPixelBufferFactory.bgra(
            width: width,
            height: height
        ) { _, _ in (32, 32, 32) }
        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess,
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        else {
            throw PosterFrameError.invalidPixelBuffer
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let bitmapInfo =
            CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            )
        else {
            throw PosterFrameError.invalidPixelBuffer
        }

        guard let font = CTFontCreateUIFontForLanguage(.system, 44, nil) else {
            throw PosterFrameError.invalidPixelBuffer
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 1, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: "A generated subtitle line",
                attributes: attributes
            )
        )
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.textPosition = CGPoint(
            x: (CGFloat(width) - lineWidth) / 2,
            y: 44
        )
        CTLineDraw(line, context)
        return pixelBuffer
    }

    private func busyLowerThirdBuffer(
        includesText: Bool
    ) throws -> CVPixelBuffer {
        let width = 640
        let height = 360
        let pixelBuffer = try TestPixelBufferFactory.bgra(
            width: width,
            height: height
        ) { x, y in
            let value = UInt8(60 + (x * 17 + y * 11) % 110)
            return (value, value, value)
        }
        guard includesText else {
            return pixelBuffer
        }
        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess,
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        else {
            throw PosterFrameError.invalidPixelBuffer
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ), let font = CTFontCreateUIFontForLanguage(.system, 40, nil)
        else {
            throw PosterFrameError.invalidPixelBuffer
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                CGColor(gray: 1, alpha: 1),
            NSAttributedString.Key(kCTStrokeColorAttributeName as String):
                CGColor(gray: 0, alpha: 1),
            NSAttributedString.Key(kCTStrokeWidthAttributeName as String): -6,
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: "A small outlined subtitle",
                attributes: attributes
            )
        )
        let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.textPosition = CGPoint(
            x: (CGFloat(width) - lineWidth) / 2,
            y: 34
        )
        CTLineDraw(line, context)
        return pixelBuffer
    }
}
