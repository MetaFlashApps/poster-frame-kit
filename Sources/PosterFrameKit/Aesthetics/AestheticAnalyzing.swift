import CoreVideo

protocol AestheticAnalyzing: Sendable {
    func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> AestheticAnalysis
}

struct AestheticAnalysis: Equatable, Sendable {
    let score: Double
    let isUtilityFrame: Bool
}

func makeAestheticAnalyzer() -> (any AestheticAnalyzing)? {
    if #available(macOS 15.0, iOS 18.0, tvOS 18.0, visionOS 2.0, *) {
        VisionAestheticAnalyzer()
    } else {
        nil
    }
}
