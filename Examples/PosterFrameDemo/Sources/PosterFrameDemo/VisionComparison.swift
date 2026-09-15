struct VisionComparison: Sendable {
    let vision: DemoComparisonResult
    let hybrid: DemoComparisonResult
    let candidateScores: [VisionCandidateScore]
}
