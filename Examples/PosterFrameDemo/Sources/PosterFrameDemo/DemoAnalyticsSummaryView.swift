import SwiftUI

struct DemoAnalyticsSummaryView: View {
    let comparison: DemoPerformanceComparison

    var body: some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.title2)
                        .bold()
                    Text(detail)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if comparison.winner == .tie {
                    Text("Within 1%")
                        .font(.title2.monospacedDigit())
                        .bold()
                } else {
                    VStack(alignment: .trailing) {
                        Text(
                            "\(comparison.speedupFactor, format: .number.precision(.fractionLength(2)))×"
                        )
                        .font(.largeTitle.monospacedDigit())
                        .bold()
                        Text("faster")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        } label: {
            Label("End-to-End Result", systemImage: "flag.checkered")
        }
    }

    private var title: String {
        switch comparison.winner {
        case .posterFrameKit:
            "PosterFrameKit wins this run"
        case .visionPipeline:
            "Vision pipeline wins this run"
        case .tie:
            "This run is effectively tied"
        }
    }

    private var detail: String {
        switch comparison.winner {
        case .posterFrameKit:
            "PosterFrameKit used \(savedPercentage) less total processing time."
        case .visionPipeline:
            "The Vision demo pipeline used \(savedPercentage) less total processing time."
        case .tie:
            "The complete workflows finished within one percent of each other."
        }
    }

    private var savedPercentage: String {
        comparison.timeSavedFraction.formatted(
            .percent.precision(.fractionLength(1))
        )
    }

    private var systemImage: String {
        switch comparison.winner {
        case .posterFrameKit:
            "bolt.fill"
        case .visionPipeline:
            "eye.fill"
        case .tie:
            "equal.circle.fill"
        }
    }

    private var tint: Color {
        switch comparison.winner {
        case .posterFrameKit:
            .accentColor
        case .visionPipeline:
            .purple
        case .tie:
            .secondary
        }
    }
}
