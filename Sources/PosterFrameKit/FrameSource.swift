import CoreGraphics
import CoreMedia
import CoreVideo

/// A source that can provide decoded video frames at requested timestamps.
///
/// An actor is a natural implementation for stateful decoders because calls
/// need to remain serialized while still presenting an asynchronous API.
public protocol PosterFrameSource: Sendable {
    /// The finite, positive source duration.
    ///
    /// - Throws: A source-specific metadata error. PosterFrameKit maps task
    ///   cancellation to ``PosterFrameError/cancelled``.
    var duration: CMTime { get async throws }

    /// Decodes a frame at or near a requested timestamp.
    ///
    /// - Parameters:
    ///   - time: Timestamp requested by PosterFrameKit.
    ///   - maximumSize: Optional maximum pixel bounds. Implementations preserve
    ///     aspect ratio and may return a smaller frame.
    /// - Returns: A display-oriented sample containing both requested and
    ///   actual timestamps.
    /// - Throws: A source-specific decoding error. PosterFrameKit maps task
    ///   cancellation to ``PosterFrameError/cancelled``.
    func frame(
        at time: CMTime,
        maximumSize: CGSize?
    ) async throws -> PosterFrameSample
}
