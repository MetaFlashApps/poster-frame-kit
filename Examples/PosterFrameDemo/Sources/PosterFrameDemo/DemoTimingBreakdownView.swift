import SwiftUI

struct DemoTimingBreakdownView: View {
    let comparison: DemoPerformanceComparison

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                DemoTimingBarView(
                    title: "PosterFrameKit",
                    systemImage: "bolt.fill",
                    duration: comparison.posterFrameDuration,
                    seconds: comparison.posterFrameSeconds,
                    maximumSeconds: comparison.maximumSeconds,
                    tint: .accentColor
                )

                DemoTimingBarView(
                    title: "Vision Demo Pipeline",
                    systemImage: "eye.fill",
                    duration: comparison.visionPipelineDuration,
                    seconds: comparison.visionPipelineSeconds,
                    maximumSeconds: comparison.maximumSeconds,
                    tint: .purple
                )

                Divider()

                LabeledContent {
                    DemoDurationValue(
                        duration: comparison.candidateCaptureDuration
                    )
                    .monospacedDigit()
                } label: {
                    Label("Candidate Capture", systemImage: "film.stack")
                }

                LabeledContent {
                    DemoDurationValue(duration: comparison.visionRankingDuration)
                        .monospacedDigit()
                } label: {
                    Label("Vision Ranking Only", systemImage: "sparkles")
                }
            }
        } label: {
            Label("Timing Breakdown", systemImage: "chart.bar.fill")
        }
    }
}
