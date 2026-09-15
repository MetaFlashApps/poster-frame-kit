import CoreGraphics
import CoreMedia
@testable import PosterFrameKit

actor StubFrameSource: PosterFrameSource {
    let duration: CMTime
    private let samples: [PosterFrameSample]
    private var nextSampleIndex = 0
    private(set) var requestedTimes: [CMTime] = []
    private(set) var requestedMaximumSizes: [CGSize?] = []

    init(duration: CMTime, samples: [PosterFrameSample]) {
        self.duration = duration
        self.samples = samples
    }

    func frame(
        at time: CMTime,
        maximumSize: CGSize?
    ) async throws -> PosterFrameSample {
        guard nextSampleIndex < samples.count else {
            throw PosterFrameError.noCandidateFrames
        }

        requestedTimes.append(time)
        requestedMaximumSizes.append(maximumSize)
        defer {
            nextSampleIndex += 1
        }
        return samples[nextSampleIndex]
    }
}
