import SwiftUI

struct DemoTimingBarView: View {
    let title: String
    let systemImage: String
    let duration: Duration
    let seconds: Double
    let maximumSeconds: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .bold()
                Spacer()
                DemoDurationValue(duration: duration)
                    .monospacedDigit()
            }

            ProgressView(value: seconds, total: maximumSeconds)
                .tint(tint)
                .accessibilityLabel("\(title) duration")
                .accessibilityValue(
                    "\(seconds.formatted(.number.precision(.fractionLength(3)))) seconds"
                )
        }
    }
}
