import SwiftUI

struct DemoMetricBarView: View {
    let title: String
    let systemImage: String
    let value: Double
    let maximumValue: Double
    let tint: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .bold()
                Spacer()
                Text(
                    value,
                    format: .number.precision(.fractionLength(3))
                )
                .monospacedDigit()
            }

            ProgressView(value: value, total: maximumValue)
                .tint(tint)
                .accessibilityLabel(title)
                .accessibilityValue(accessibilityValue)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private var accessibilityValue: String {
        let formattedValue = value.formatted(
            .number.precision(.fractionLength(3))
        )
        let formattedMaximum = maximumValue.formatted(
            .number.precision(.fractionLength(1))
        )
        return "\(formattedValue) out of \(formattedMaximum)"
    }
}
