import CoreVideo

@testable import PosterFrameKit

final class StubAestheticAnalyzer: AestheticAnalyzing, @unchecked Sendable {
    private var results: [Result<AestheticAnalysis, PosterFrameError>]
    private(set) var callCount = 0

    init(results: [Result<AestheticAnalysis, PosterFrameError>]) {
        self.results = results
    }

    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> AestheticAnalysis {
        callCount += 1
        guard !results.isEmpty else {
            return AestheticAnalysis(score: 0, isUtilityFrame: false)
        }
        return try results.removeFirst().get()
    }
}
