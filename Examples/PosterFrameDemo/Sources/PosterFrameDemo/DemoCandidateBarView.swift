import SwiftUI

struct DemoCandidateBarView: View {
    let candidate: DemoCandidateFrame
    let position: Int
    let totalCount: Int
    let isRecommendation: Bool
    let isBrowsed: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isRecommendation ? Color.green : Color.secondary.opacity(0.2))
                .frame(height: max(6, candidate.baseScore * 46))
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .bottom)
        .background(
            isBrowsed ? Color.accentColor.opacity(0.14) : Color.clear,
            in: .rect(cornerRadius: 6)
        )
        .overlay(alignment: .topTrailing) {
            if isRecommendation {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if isBrowsed {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isBrowsed ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        let timestamp = DemoTimestampFormatter.string(from: candidate.time)
            ?? "unavailable time"
        let score = candidate.baseScore.formatted(
            .number.precision(.fractionLength(3))
        )
        let recommendation = isRecommendation
            ? ", PosterFrameKit recommendation"
            : ""
        let metrics = candidate.metrics
        let brightness = formatted(metrics.meanLuma)
        let contrast = formatted(metrics.lumaDeviation)
        let entropy = formatted(metrics.entropy)
        let sharpness = formatted(metrics.sharpness)
        let color = formatted(metrics.colorfulness)
        let noise = formatted(metrics.visualNoise)
        return """
            Candidate \(position) of \(totalCount), \(timestamp), base score \(score), \
            brightness \(brightness), contrast \(contrast), entropy \(entropy), \
            sharpness \(sharpness), color \(color), noise \(noise)\(recommendation)
            """
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }
}
