import PosterFrameKit

struct ExampleMetric: Identifiable {
  let id: String
  let title: String
  let value: Double

  static func all(from metrics: FrameMetrics) -> [ExampleMetric] {
    [
      ExampleMetric(id: "luma", title: "Luma", value: metrics.meanLuma),
      ExampleMetric(
        id: "contrast",
        title: "Contrast",
        value: metrics.lumaDeviation
      ),
      ExampleMetric(id: "entropy", title: "Entropy", value: metrics.entropy),
      ExampleMetric(
        id: "sharpness",
        title: "Sharpness",
        value: metrics.sharpness
      ),
      ExampleMetric(
        id: "colorfulness",
        title: "Colorfulness",
        value: metrics.colorfulness
      ),
      ExampleMetric(
        id: "noise",
        title: "Visual Noise",
        value: metrics.visualNoise
      ),
    ]
  }
}
