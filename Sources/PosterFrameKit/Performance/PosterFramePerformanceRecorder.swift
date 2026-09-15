import Foundation

package struct PosterFramePerformanceSnapshot: Codable, Equatable, Sendable {
    package let metadataMilliseconds: Double
    package let seekAndDecodeMilliseconds: Double
    package let imageConversionMilliseconds: Double
    package let analysisAndRankingMilliseconds: Double
    package let resultImageConversionMilliseconds: Double
    package let subtitleAnalysisMilliseconds: Double
    package let faceAnalysisMilliseconds: Double
    package let aestheticAnalysisMilliseconds: Double
    package let decodedFrameCount: Int
    package let analyzedFrameCount: Int
    package let subtitleAnalyzedFrameCount: Int
    package let subtitleAccurateFallbackCount: Int
    package let faceAnalyzedFrameCount: Int
    package let aestheticAnalyzedFrameCount: Int
    package let peakConcurrentDecodes: Int
}

package actor PosterFramePerformanceRecorder {
    private var metadataMilliseconds = 0.0
    private var seekAndDecodeMilliseconds = 0.0
    private var imageConversionMilliseconds = 0.0
    private var analysisAndRankingMilliseconds = 0.0
    private var resultImageConversionMilliseconds = 0.0
    private var subtitleAnalysisMilliseconds = 0.0
    private var faceAnalysisMilliseconds = 0.0
    private var aestheticAnalysisMilliseconds = 0.0
    private var decodedFrameCount = 0
    private var analyzedFrameCount = 0
    private var subtitleAnalyzedFrameCount = 0
    private var subtitleAccurateFallbackCount = 0
    private var faceAnalyzedFrameCount = 0
    private var aestheticAnalyzedFrameCount = 0
    private var activeDecodes = 0
    private var peakConcurrentDecodes = 0

    package init() {}

    package func decodeStarted() {
        activeDecodes += 1
        peakConcurrentDecodes = max(peakConcurrentDecodes, activeDecodes)
    }

    package func decodeFinished(after duration: Duration) {
        activeDecodes = max(0, activeDecodes - 1)
        seekAndDecodeMilliseconds += duration.milliseconds
        decodedFrameCount += 1
    }

    package func recordMetadata(_ duration: Duration) {
        metadataMilliseconds += duration.milliseconds
    }

    package func recordImageConversion(_ duration: Duration) {
        imageConversionMilliseconds += duration.milliseconds
    }

    package func recordAnalysisAndRanking(_ duration: Duration) {
        analysisAndRankingMilliseconds += duration.milliseconds
        analyzedFrameCount += 1
    }

    package func recordResultImageConversion(_ duration: Duration) {
        resultImageConversionMilliseconds += duration.milliseconds
    }

    package func recordSubtitleAnalysis(
        _ duration: Duration,
        usedAccurateRecognition: Bool
    ) {
        subtitleAnalysisMilliseconds += duration.milliseconds
        subtitleAnalyzedFrameCount += 1
        if usedAccurateRecognition {
            subtitleAccurateFallbackCount += 1
        }
    }

    package func recordFaceAnalysis(_ duration: Duration) {
        faceAnalysisMilliseconds += duration.milliseconds
        faceAnalyzedFrameCount += 1
    }

    package func recordAestheticAnalysis(_ duration: Duration) {
        aestheticAnalysisMilliseconds += duration.milliseconds
        aestheticAnalyzedFrameCount += 1
    }

    package func snapshot() -> PosterFramePerformanceSnapshot {
        PosterFramePerformanceSnapshot(
            metadataMilliseconds: metadataMilliseconds,
            seekAndDecodeMilliseconds: seekAndDecodeMilliseconds,
            imageConversionMilliseconds: imageConversionMilliseconds,
            analysisAndRankingMilliseconds: analysisAndRankingMilliseconds,
            resultImageConversionMilliseconds: resultImageConversionMilliseconds,
            subtitleAnalysisMilliseconds: subtitleAnalysisMilliseconds,
            faceAnalysisMilliseconds: faceAnalysisMilliseconds,
            aestheticAnalysisMilliseconds: aestheticAnalysisMilliseconds,
            decodedFrameCount: decodedFrameCount,
            analyzedFrameCount: analyzedFrameCount,
            subtitleAnalyzedFrameCount: subtitleAnalyzedFrameCount,
            subtitleAccurateFallbackCount: subtitleAccurateFallbackCount,
            faceAnalyzedFrameCount: faceAnalyzedFrameCount,
            aestheticAnalyzedFrameCount: aestheticAnalyzedFrameCount,
            peakConcurrentDecodes: peakConcurrentDecodes
        )
    }
}

extension Duration {
    fileprivate var milliseconds: Double {
        let components = self.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
