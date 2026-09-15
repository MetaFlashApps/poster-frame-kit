import CoreGraphics
import CoreMedia

/// `CGImage` is immutable, so passing the generated preview back to the main
/// actor is safe even though Core Graphics does not declare Sendable here.
struct BaselineFrame: @unchecked Sendable {
    let image: CGImage
    let time: CMTime
    let duration: CMTime
}
