/// A preset or custom weighting strategy for poster-frame scoring.
public enum PosterFrameProfile: Equatable, Sendable {
    /// Balanced weights suitable for varied material.
    case general

    /// Weights favoring crisp edges and controlled contrast in animation.
    case animation

    /// Caller-defined scoring weights.
    case custom(PosterFrameWeights)
}
