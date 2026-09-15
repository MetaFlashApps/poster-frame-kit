import PosterFrameKit
import SwiftUI

struct DemoHeroMetricsView: View {
    let metrics: FrameMetrics?

    var body: some View {
        if let metrics {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 10)],
                alignment: .leading,
                spacing: 8
            ) {
                DemoHeroMetricBarView(
                    title: "Brightness",
                    value: metrics.meanLuma,
                    maximumValue: 1,
                    tint: .yellow,
                    help: "Average normalized luma."
                )
                DemoHeroMetricBarView(
                    title: "Contrast",
                    value: metrics.lumaDeviation,
                    maximumValue: 0.5,
                    tint: .blue,
                    help: "Population deviation of normalized luma."
                )
                DemoHeroMetricBarView(
                    title: "Entropy",
                    value: metrics.entropy,
                    maximumValue: 1,
                    tint: .indigo,
                    help: "Information density in the luma histogram."
                )
                DemoHeroMetricBarView(
                    title: "Sharpness",
                    value: metrics.sharpness,
                    maximumValue: 1,
                    tint: .mint,
                    help: "Normalized Tenengrad edge strength."
                )
                DemoHeroMetricBarView(
                    title: "Color",
                    value: metrics.colorfulness,
                    maximumValue: 1,
                    tint: .pink,
                    help: "Average normalized chroma magnitude."
                )
                DemoHeroMetricBarView(
                    title: "Noise",
                    value: metrics.visualNoise,
                    maximumValue: 1,
                    tint: .orange,
                    help: "Dense incoherent high-frequency detail."
                )
            }
        }
    }
}
