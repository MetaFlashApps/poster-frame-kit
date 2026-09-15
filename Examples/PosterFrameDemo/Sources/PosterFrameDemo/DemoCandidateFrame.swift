import CoreGraphics
import CoreMedia
import PosterFrameKit

/// A display-sized representation of one decoded comparison candidate.
/// The immutable thumbnail is safe to pass across concurrency domains even
/// though Core Graphics does not declare `CGImage` as `Sendable`.
struct DemoCandidateFrame: Identifiable, @unchecked Sendable {
    let id: Int
    let thumbnail: CGImage
    let time: CMTime
    let baseScore: Double
    let metrics: FrameMetrics
}
