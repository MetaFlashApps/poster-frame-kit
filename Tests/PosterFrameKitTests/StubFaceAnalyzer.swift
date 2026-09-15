import CoreVideo

@testable import PosterFrameKit

final class StubFaceAnalyzer: FaceAnalyzing, @unchecked Sendable {
    private var results: [Result<FaceAnalysis, PosterFrameError>]
    private(set) var callCount = 0

    init(results: [Result<FaceAnalysis, PosterFrameError>]) {
        self.results = results
    }

    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> FaceAnalysis {
        callCount += 1
        guard !results.isEmpty else {
            return .none
        }
        return try results.removeFirst().get()
    }
}
