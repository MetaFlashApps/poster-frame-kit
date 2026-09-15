import PosterFrameKit
import SwiftUI

struct DemoResultMetricsView: View {
    let metrics: FrameMetrics

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "Each bar uses the metric's documented range. These measurements explain the base ranking; they are not independent quality grades."
                )
                .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 260), spacing: 16)
                    ],
                    alignment: .leading,
                    spacing: 16
                ) {
                    DemoMetricBarView(
                        title: "Brightness",
                        systemImage: "sun.max.fill",
                        value: metrics.meanLuma,
                        maximumValue: 1,
                        tint: .yellow,
                        detail: "Average normalized luma."
                    )
                    DemoMetricBarView(
                        title: "Contrast",
                        systemImage: "circle.lefthalf.filled",
                        value: metrics.lumaDeviation,
                        maximumValue: 0.5,
                        tint: .blue,
                        detail: "Population deviation of normalized luma."
                    )
                    DemoMetricBarView(
                        title: "Entropy",
                        systemImage: "square.grid.3x3.fill",
                        value: metrics.entropy,
                        maximumValue: 1,
                        tint: .indigo,
                        detail: "Information density in the luma histogram."
                    )
                    DemoMetricBarView(
                        title: "Sharpness",
                        systemImage: "scope",
                        value: metrics.sharpness,
                        maximumValue: 1,
                        tint: .mint,
                        detail: "Normalized Tenengrad edge strength."
                    )
                    DemoMetricBarView(
                        title: "Colorfulness",
                        systemImage: "paintpalette.fill",
                        value: metrics.colorfulness,
                        maximumValue: 1,
                        tint: .pink,
                        detail: "Average normalized chroma magnitude."
                    )
                    DemoMetricBarView(
                        title: "Visual Noise",
                        systemImage: "waveform.path.ecg",
                        value: metrics.visualNoise,
                        maximumValue: 1,
                        tint: .orange,
                        detail: "Dense incoherent high-frequency detail."
                    )
                }
            }
        } label: {
            Label("Image Measurements", systemImage: "chart.bar.fill")
        }
    }
}
