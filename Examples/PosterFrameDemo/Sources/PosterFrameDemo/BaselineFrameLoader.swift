import AVFoundation

enum BaselineFrameLoader {
    nonisolated static func load(from url: URL) async throws -> BaselineFrame {
        try Task.checkCancellation()

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationInSeconds = duration.seconds

        guard durationInSeconds.isFinite, durationInSeconds > 0 else {
            throw DemoFrameError.invalidDuration
        }

        let requestedTime = CMTime(
            seconds: durationInSeconds * 0.5,
            preferredTimescale: 600
        )
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1_280, height: 720)

        let generated = try await generator.image(at: requestedTime)
        try Task.checkCancellation()

        return BaselineFrame(
            image: generated.image,
            time: generated.actualTime,
            duration: duration
        )
    }
}
