import Foundation

enum DemoFrameError: LocalizedError {
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            "The video does not have a usable duration."
        }
    }
}
