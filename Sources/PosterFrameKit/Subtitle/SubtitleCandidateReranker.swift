import CoreMedia

struct SubtitleCandidateReranker {
    let analyzer: any SubtitleAnalyzing
    let options: PosterFrameSubtitleOptions
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

        if options.maximumPenalty == 0 {
            let count = analyzeAll ? options.candidateCount : 1
            return Array(eligibleCandidates.prefix(count))
                + ineligibleCandidates
        }

        var ranked: [RefinedCandidate] = []
        var winner: RefinedCandidate?

        for candidate in eligibleCandidates {
            if !analyzeAll,
                let winner,
                Self.cannotOutrankWinnerWithoutPenalty(candidate, winner: winner)
            {
                break
            }

            let analysisStart = ContinuousClock.now
            let analysis = try await analyzer.analyze(
                candidate.candidate.pixelBuffer
            )
            if let performanceRecorder {
                await performanceRecorder.recordSubtitleAnalysis(
                    analysisStart.duration(to: .now),
                    usedAccurateRecognition: analysis.usedAccurateRecognition
                )
            }
            var rankedCandidate = candidate
            rankedCandidate.subtitlePenalty =
                min(
                    max(analysis.likelihood, 0),
                    1
                ) * options.maximumPenalty
            ranked.append(rankedCandidate)
            if let currentWinner = winner {
                if rankedCandidate.isPreferred(over: currentWinner) {
                    winner = rankedCandidate
                }
            } else {
                winner = rankedCandidate
            }
        }

        let uninspected = eligibleCandidates.dropFirst(ranked.count)
        return (ranked + uninspected + ineligibleCandidates).sorted {
            $0.isPreferred(over: $1)
        }
    }

    private static func cannotOutrankWinnerWithoutPenalty(
        _ candidate: RefinedCandidate,
        winner: RefinedCandidate
    ) -> Bool {
        if candidate.scoreBeforeSubtitlePenalty != winner.adjustedScore {
            return candidate.scoreBeforeSubtitlePenalty < winner.adjustedScore
        }
        return CMTimeCompare(
            candidate.candidate.time,
            winner.candidate.time
        ) >= 0
    }
}
