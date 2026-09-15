import SwiftUI

struct ExampleMetricView: View {
  let metric: ExampleMetric

  var body: some View {
    VStack(alignment: .leading) {
      Text(metric.title)
        .foregroundStyle(.secondary)

      Text(metric.value, format: .number.precision(.fractionLength(3)))
        .font(.headline.monospacedDigit())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary)
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(metric.title)
    .accessibilityValue(
      Text(metric.value, format: .number.precision(.fractionLength(3)))
    )
  }
}
