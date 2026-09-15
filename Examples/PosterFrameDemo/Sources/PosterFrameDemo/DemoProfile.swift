import PosterFrameKit

enum DemoProfile: CaseIterable, Identifiable {
    case general
    case animation

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            "General"
        case .animation:
            "Animation"
        }
    }

    var posterFrameProfile: PosterFrameProfile {
        switch self {
        case .general:
            .general
        case .animation:
            .animation
        }
    }
}
