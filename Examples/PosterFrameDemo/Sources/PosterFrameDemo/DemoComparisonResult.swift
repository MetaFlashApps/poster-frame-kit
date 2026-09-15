import CoreGraphics
import CoreMedia

struct DemoComparisonResult: @unchecked Sendable {
    let image: CGImage
    let time: CMTime
    let score: Double
    let isUtility: Bool
}
