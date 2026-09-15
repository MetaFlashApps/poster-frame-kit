import SwiftUI

struct DemoScoreComponentRow: View {
    let title: String
    let systemImage: String
    let value: Double
    let tint: Color
    let isSigned: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(formattedValue)
                .monospacedDigit()
                .bold()
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }

    private var formattedValue: String {
        if isSigned {
            value.formatted(
                .percent
                    .sign(strategy: .always())
                    .precision(.fractionLength(1))
            )
        } else {
            value.formatted(.percent.precision(.fractionLength(1)))
        }
    }
}
