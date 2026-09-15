import CoreGraphics
import CoreImage
import CoreMedia
import PosterFrameKit

enum DemoCandidatePreviewLoader {
    static func load(
        from url: URL,
        at time: CMTime,
        maximumSize: CGSize
    ) async throws -> CGImage {
        let source = AVFoundationFrameSource(url: url)
        let sample = try await source.frame(at: time, maximumSize: maximumSize)
        try Task.checkCancellation()

        let image = CIImage(cvPixelBuffer: sample.pixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let result = context.createCGImage(image, from: image.extent) else {
            throw PosterFrameError.imageCreationFailed
        }
        return result
    }
}
