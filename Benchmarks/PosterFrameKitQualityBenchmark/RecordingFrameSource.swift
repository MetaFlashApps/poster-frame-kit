import CoreGraphics
import CoreMedia
import PosterFrameKit

actor RecordingFrameSource: PosterFrameSource {
    private let source: AVFoundationFrameSource
    private var recordedSamples: [PosterFrameSample] = []

    init(url: URL) {
        source = AVFoundationFrameSource(url: url)
    }

    var duration: CMTime {
        get async throws {
            try await source.duration
        }
    }

    func frame(
        at time: CMTime,
        maximumSize: CGSize?
    ) async throws -> PosterFrameSample {
        let sample = try await source.frame(at: time, maximumSize: maximumSize)
        if !recordedSamples.contains(where: {
            CMTimeCompare($0.actualTime, sample.actualTime) == 0
        }) {
            recordedSamples.append(sample)
        }
        return sample
    }

    func samples() -> [PosterFrameSample] {
        recordedSamples
    }
}
