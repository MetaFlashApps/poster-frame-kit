struct ProfileWeights {
    static func weights(for profile: PosterFrameProfile) -> PosterFrameWeights {
        switch profile {
        case .general:
            PosterFrameWeights(
                sharpness: 0.35,
                contrast: 0.25,
                entropy: 0.30,
                colorfulness: 0.10
            )
        case .animation:
            PosterFrameWeights(
                sharpness: 0.40,
                contrast: 0.30,
                entropy: 0.25,
                colorfulness: 0.05
            )
        case .custom(let weights):
            weights
        }
    }
}
