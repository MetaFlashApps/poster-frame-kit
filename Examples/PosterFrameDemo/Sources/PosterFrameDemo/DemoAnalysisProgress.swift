import PosterFrameKit

enum DemoAnalysisProgress: Sendable {
    case selected(PosterFrameResult, duration: Duration)
    case stage(DemoAnalysisStage)
}
