import CoreMedia
import CoreVideo

/// A decoded frame and its requested and actual timestamps.
///
/// The conformance is unchecked because Core Video does not declare pixel
/// buffers as `Sendable`. A source must not mutate a returned buffer while
/// PosterFrameKit is analyzing it.
public struct PosterFrameSample: @unchecked Sendable {
    /// Display-oriented pixel data for the frame.
    public let pixelBuffer: CVPixelBuffer

    /// Timestamp originally requested from the source.
    public let requestedTime: CMTime

    /// Timestamp of the frame the decoder actually returned.
    public let actualTime: CMTime

    /// Creates a decoded frame sample.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Display-oriented decoded pixel data.
    ///   - requestedTime: Timestamp requested from the decoder.
    ///   - actualTime: Timestamp of the frame returned by the decoder.
    public init(
        pixelBuffer: CVPixelBuffer,
        requestedTime: CMTime,
        actualTime: CMTime
    ) {
        self.pixelBuffer = pixelBuffer
        self.requestedTime = requestedTime
        self.actualTime = actualTime
    }
}
