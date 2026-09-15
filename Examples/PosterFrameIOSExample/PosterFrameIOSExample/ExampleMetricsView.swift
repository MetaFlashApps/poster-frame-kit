import PosterFrameKit
import SwiftUI

struct ExampleMetricsView: View {
  private let metrics: [ExampleMetric]

  init(metrics: FrameMetrics) {
    self.metrics = ExampleMetric.all(from: metrics)
  }

  var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
      spacing: 12
    ) {
      ForEach(metrics) { metric in
        ExampleMetricView(metric: metric)
      }
    }
  }
}
