import SwiftUI

struct DemoHeroMetricBarView: View {
    let title: String
    let value: Double
    let maximumValue: Double
    let tint: Color
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                Spacer()
                Text(value, format: .number.precision(.fractionLength(3)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ProgressView(value: value, total: maximumValue)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue(
                    value.formatted(.number.precision(.fractionLength(3)))
                )
        }
        .help(help)
    }
}
