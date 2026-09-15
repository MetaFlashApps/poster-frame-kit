import CoreMedia

struct CandidatePool {
  private let retainedCandidateCount: Int
  private(set) var bestCandidate: EvaluatedCandidate?
  private(set) var refinementCandidates: [EvaluatedCandidate] = []
  private(set) var lastDecodingError: (error: any Error, candidateIndex: Int)?
  private var evaluatedTimes: [CMTime] = []

  init(retainedCandidateCount: Int) {
    self.retainedCandidateCount = max(retainedCandidateCount, 0)
  }

  mutating func register(actualTime: CMTime) -> Bool {
    guard actualTime.isValid, actualTime.isNumeric else {
      return false
    }
    guard
      !evaluatedTimes.contains(where: {
        CMTimeCompare($0, actualTime) == 0
      })
    else {
      return false
    }
    evaluatedTimes.append(actualTime)
    return true
  }

  mutating func insert(_ candidate: EvaluatedCandidate) {
    if candidate.isPreferred(over: bestCandidate) {
      bestCandidate = candidate
    }
    guard retainedCandidateCount > 0 else {
      return
    }

    refinementCandidates.append(candidate)
    refinementCandidates.sort { $0.isPreferred(over: $1) }
    if refinementCandidates.count > retainedCandidateCount {
      refinementCandidates.removeLast(
        refinementCandidates.count - retainedCandidateCount
      )
    }
  }

  mutating func recordDecodingError(_ error: any Error, candidateIndex: Int) {
    guard candidateIndex >= (lastDecodingError?.candidateIndex ?? -1) else {
      return
    }
    lastDecodingError = (error, candidateIndex)
  }
}
