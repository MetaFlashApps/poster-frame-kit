import PosterFrameKit
import SwiftUI

struct DemoScoreSummaryView: View {
    let result: PosterFrameResult

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .frame(width: 52, height: 52)
                        .background(
                            Color.accentColor.opacity(0.14),
                            in: .rect(cornerRadius: 12)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading) {
                        Text("Final Ranking Score")
                            .foregroundStyle(.secondary)
                        Text(
                            result.adjustedScore,
                            format: .percent.precision(.fractionLength(1))
                        )
                        .font(.largeTitle.monospacedDigit())
                        .bold()
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing) {
                        Text("Selected Timestamp")
                            .foregroundStyle(.secondary)
                        Text(
                            DemoTimestampFormatter.string(from: result.time)
                                ?? "Unavailable"
                        )
                        .font(.title2.monospacedDigit())
                        .bold()
                    }
                }

                ProgressView(value: result.adjustedScore, total: 1)
                    .tint(.accentColor)
                    .accessibilityLabel("Final ranking score")
                    .accessibilityValue(
                        result.adjustedScore.formatted(
                            .percent.precision(.fractionLength(1))
                        )
                    )
            }
            .padding(.vertical, 8)
        } label: {
            Label("Selected Candidate", systemImage: "photo.badge.checkmark")
        }
    }
}
