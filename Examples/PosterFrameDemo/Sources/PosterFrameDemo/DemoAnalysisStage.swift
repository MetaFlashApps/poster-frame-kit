enum DemoAnalysisStage: Equatable, Sendable {
    case posterFrameKit
    case comparisonCapture
    case vision

    var progressTitle: String {
        switch self {
        case .posterFrameKit:
            "PosterFrameKit is analyzing candidates…"
        case .comparisonCapture:
            "Capturing candidates for the Vision comparison…"
        case .vision:
            "Apple Vision is ranking captured candidates…"
        }
    }
}
