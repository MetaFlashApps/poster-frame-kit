import CoreMedia

struct FaceCandidateReranker {
    let analyzer: any FaceAnalyzing
    let options: PosterFrameFaceOptions
    let performanceRecorder: PosterFramePerformanceRecorder?

    func rank(
        _ candidates: [RefinedCandidate],
        analyzeAll: Bool
    ) async throws -> [RefinedCandidate] {
        let candidates = candidates.sorted { $0.isPreferred(over: $1) }
        let eligibleCandidates = candidates.prefix(options.candidateCount)
        let ineligibleCandidates = candidates.dropFirst(options.candidateCount)

        guard options.maximumBonus > 0 else {
            return candidates
        }

        var ranked: [RefinedCandidate] = []
        var winner: RefinedCandidate?

        for candidate in eligibleCandidates {
            if !analyzeAll,
                let winner,
                Self.cannotOutrankWinnerWithMaximumBonus(
                    candidate,
                    winner: winner,
                    maximumBonus: options.maximumBonus
                )
            {
                break
            }

            let analysisStart = ContinuousClock.now
            let analysis = try await analyzer.analyze(
                candidate.candidate.pixelBuffer
            )
            if let performanceRecorder {
                await performanceRecorder.recordFaceAnalysis(
                    analysisStart.duration(to: .now)
                )
            }
            var rankedCandidate = candidate
            rankedCandidate.faceCompositionBonus =
                min(
                    max(
                        FaceCompositionScorer.quality(
                            for: analysis.faceBounds,
                            confidences: analysis.faceConfidences
                        ),
                        0
                    ),
                    1
                ) * options.maximumBonus
            ranked.append(rankedCandidate)

            if let currentWinner = winner {
                if rankedCandidate.isPreferred(over: currentWinner) {
                    winner = rankedCandidate
                }
            } else {
                winner = rankedCandidate
            }
        }

        return (ranked + Array(ineligibleCandidates)).sorted {
            $0.isPreferred(over: $1)
        }
    }

    private static func cannotOutrankWinnerWithMaximumBonus(
        _ candidate: RefinedCandidate,
        winner: RefinedCandidate,
        maximumBonus: Double
    ) -> Bool {
        let maximumScore = min(
            candidate.candidate.score + maximumBonus,
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
