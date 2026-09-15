import CoreMedia
import SwiftUI

struct DemoSelectionComparisonView: View {
    let posterFrameTime: CMTime
    let visionTime: CMTime

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    timesMatch ? "Same decoded frame" : "Different selections",
                    systemImage: timesMatch
                        ? "checkmark.circle.fill"
                        : "arrow.triangle.branch"
                )
                .foregroundStyle(timesMatch ? Color.green : Color.secondary)

                LabeledContent("PosterFrameKit") {
                    Text(timestamp(for: posterFrameTime))
                        .monospacedDigit()
                }
                LabeledContent("Apple Vision") {
                    Text(timestamp(for: visionTime))
                        .monospacedDigit()
                }

                Text(
                    "Quality scores use different scales and are intentionally not compared as if they were equivalent."
                )
                .foregroundStyle(.secondary)
            }
        } label: {
            Label("Selection Outcome", systemImage: "photo.stack")
        }
    }

    private var timesMatch: Bool {
        CMTimeCompare(posterFrameTime, visionTime) == 0
    }

    private func timestamp(for time: CMTime) -> String {
        DemoTimestampFormatter.string(from: time) ?? "Unavailable"
    }
}
