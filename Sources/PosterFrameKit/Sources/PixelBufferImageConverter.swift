import CoreImage
import CoreVideo

enum PixelBufferImageConverter {
    // CIContext is immutable and thread-safe. Reusing it avoids rebuilding the
    // context's rendering state for every selected frame.
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func image(from pixelBuffer: CVPixelBuffer) throws -> CGImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let result = context.createCGImage(image, from: image.extent) else {
            throw PosterFrameError.imageCreationFailed
        }
        return result
    }
}
