import SwiftUI

struct DemoDurationValue: View {
    let duration: Duration

    var body: some View {
        Text(
            "\(seconds, format: .number.precision(.fractionLength(3))) s"
        )
    }

    private var seconds: Double {
        let components = duration.components
        return Double(components.seconds)
            + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
