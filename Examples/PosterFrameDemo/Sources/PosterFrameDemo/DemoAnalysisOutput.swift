struct DemoAnalysisOutput: Sendable {
    let comparisonCaptureDuration: Duration?
    let visionDuration: Duration?
    let candidateFrames: [DemoCandidateFrame]
    let visionResult: DemoComparisonResult?
    let hybridResult: DemoComparisonResult?
    let comparisonErrorMessage: String?
}
