import CoreVideo
@testable import PosterFrameKit

final class StubSubtitleAnalyzer: SubtitleAnalyzing, @unchecked Sendable {
    private var results: [Result<SubtitleAnalysis, PosterFrameError>]
    private(set) var callCount = 0

    init(results: [Result<SubtitleAnalysis, PosterFrameError>]) {
        self.results = results
    }

    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> SubtitleAnalysis {
        callCount += 1
        guard !results.isEmpty else {
            return .none
        }
        return try results.removeFirst().get()
    }
}
