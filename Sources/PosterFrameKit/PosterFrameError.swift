import Foundation

/// Errors reported by PosterFrameKit's validation and selection pipeline.
public enum PosterFrameError: Error, Equatable, Sendable {
    /// One or more option values are invalid.
    case invalidOptions(String)

    /// AVFoundation or the provided source cannot decode the input.
    case unsupportedVideo

    /// The input does not contain a video track.
    case noVideoTrack

    /// The source duration is invalid, indefinite, or empty.
    case invalidDuration

    /// No requested timestamp produced an analyzable frame.
    case noCandidateFrames

    /// The source returned a pixel buffer without usable dimensions or memory.
    case invalidPixelBuffer

    /// The source returned a pixel format unsupported by the deterministic
    /// analysis path.
    case unsupportedPixelFormat(UInt32)

    /// The selected pixel buffer could not be converted to a `CGImage`.
    case imageCreationFailed

    /// The calling task was cancelled.
    case cancelled
}

extension PosterFrameError: LocalizedError {
    /// A localized description suitable for presentation to a user.
    public var errorDescription: String? {
        switch self {
        case .invalidOptions(let message):
            "Invalid poster-frame options: \(message)."
        case .unsupportedVideo:
            "The video could not be decoded."
        case .noVideoTrack:
            "The file does not contain a video track."
        case .invalidDuration:
            "The video does not have a finite, positive duration."
        case .noCandidateFrames:
            "No candidate frames could be decoded and analyzed."
        case .invalidPixelBuffer:
            "A decoded frame contains invalid pixel data."
        case .unsupportedPixelFormat(let format):
            "The decoded pixel format \(format) is not supported."
        case .imageCreationFailed:
            "The selected frame could not be converted to an image."
        case .cancelled:
            "Poster-frame selection was cancelled."
        }
    }
}
