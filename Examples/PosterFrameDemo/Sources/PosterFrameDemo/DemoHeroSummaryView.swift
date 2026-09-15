import SwiftUI

struct DemoHeroSummaryView: View {
    let videoPosition: DemoVideoPosition?
    let score: Double?

    var body: some View {
        HStack(spacing: 8) {
            if let videoPosition {
                Text(
                    DemoTimestampFormatter.string(
                        from: videoPosition.timestampSeconds
                    ) ?? "Unavailable"
                )
                .monospacedDigit()
            }

            if let score {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(score, format: .number.precision(.fractionLength(3)))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
