import SwiftUI

struct ExampleResultView: View {
  let fileName: String
  let selection: ExampleSelection

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Image(
          selection.result.image,
          scale: 1,
          label: Text("Selected poster frame")
        )
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity)
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 16))

        Text(fileName)
          .font(.headline)
          .lineLimit(2)

        LabeledContent("Timestamp") {
          Text(timestamp)
            .monospacedDigit()
        }

        LabeledContent("Score") {
          Text(
            selection.result.adjustedScore,
            format: .percent.precision(.fractionLength(1))
          )
          .monospacedDigit()
        }

        LabeledContent("End to end") {
          Text(elapsed)
            .monospacedDigit()
        }

        Divider()

        Text("Public Metrics")
          .font(.headline)

        ExampleMetricsView(metrics: selection.result.metrics)
      }
      .padding()
    }
    .scrollContentBackground(.visible)
  }

  private var timestamp: String {
    ExampleTimestampFormatter.string(from: selection.result.time)
      ?? "Unavailable"
  }

  private var elapsed: String {
    selection.elapsed.formatted(
      .units(
        allowed: [.seconds, .milliseconds],
        width: .abbreviated,
        maximumUnitCount: 2,
        fractionalPart: .show(length: 1)
      )
    )
  }
}
