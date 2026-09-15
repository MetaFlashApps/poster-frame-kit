import CoreMedia

struct AestheticCandidateReranker {
    let analyzer: any AestheticAnalyzing
    let options: PosterFrameAestheticOptions
    let performanceRecorder: PosterFramePerformanceRecorder?

    func rank(
        _ candidates: [RefinedCandidate],
        analyzeAll: Bool
    ) async throws -> [RefinedCandidate] {
        let candidates = candidates.sorted { $0.isPreferred(over: $1) }
        let eligibleCandidates = Array(candidates.prefix(options.candidateCount))
        let ineligibleCandidates = Array(
            candidates.dropFirst(options.candidateCount)
        )

        guard options.maximumAdjustment > 0 else {
            return candidates
        }

        var analyzed: [RefinedCandidate] = []
        var winner: RefinedCandidate?

        for candidate in eligibleCandidates {
            if !analyzeAll,
                let winner,
                Self.cannotOutrankWinnerWithMaximumAdjustment(
                    candidate,
                    winner: winner,
                    maximumAdjustment: options.maximumAdjustment
                )
            {
                break
            }

            let analysisStart = ContinuousClock.now
            let analysis = try await analyzer.analyze(
                candidate.candidate.pixelBuffer
            )
            if let performanceRecorder {
                await performanceRecorder.recordAestheticAnalysis(
                    analysisStart.duration(to: .now)
                )
            }

            var rankedCandidate = candidate
            let score = min(max(analysis.score, -1), 1)
            let normalizedScore = (score + 1) / 2
            let desiredAdjustment =
                normalizedScore - candidate.candidate.score
            rankedCandidate.aestheticScore = score
            rankedCandidate.isUtilityFrame = analysis.isUtilityFrame
            rankedCandidate.aestheticAdjustment =
                min(
                    max(desiredAdjustment, -options.maximumAdjustment),
                    options.maximumAdjustment
                )
            analyzed.append(rankedCandidate)

            if let currentWinner = winner {
                if rankedCandidate.isPreferred(over: currentWinner) {
                    winner = rankedCandidate
                }
            } else {
                winner = rankedCandidate
            }
        }

        let uninspected = eligibleCandidates.dropFirst(analyzed.count)
        return (analyzed + uninspected + ineligibleCandidates).sorted {
            $0.isPreferred(over: $1)
        }
    }

    private static func cannotOutrankWinnerWithMaximumAdjustment(
        _ candidate: RefinedCandidate,
        winner: RefinedCandidate,
        maximumAdjustment: Double
    ) -> Bool {
        let maximumScore = min(
            max(candidate.adjustedScore + maximumAdjustment, 0),
            1
        )
        if maximumScore != winner.adjustedScore {
            return maximumScore < winner.adjustedScore
        }
        return CMTimeCompare(
            candidate.candidate.time,
            winner.candidate.time
        ) >= 0
    }
}
