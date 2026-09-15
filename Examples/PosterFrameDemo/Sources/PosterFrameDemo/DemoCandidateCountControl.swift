import SwiftUI

struct DemoCandidateCountControl: View {
    @Binding private var value: Int
    @State private var sliderValue: Double

    init(value: Binding<Int>) {
        _value = value
        _sliderValue = State(initialValue: Double(value.wrappedValue))
    }

    var body: some View {
        LabeledContent("Candidates") {
            HStack {
                Slider(value: $sliderValue, in: 8...80, step: 8)
                    .onChange(of: sliderValue, updateValue)
                    .accessibilityValue("\(value) candidates")

                Text(value, format: .number)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .onChange(of: value, updateSlider)
    }

    private func updateValue(
        _ oldValue: Double,
        _ newValue: Double
    ) {
        let candidateCount = Int(newValue)
        if value != candidateCount {
            value = candidateCount
        }
    }

    private func updateSlider(
        _ oldValue: Int,
        _ newValue: Int
    ) {
        let newSliderValue = Double(newValue)
        if sliderValue != newSliderValue {
            sliderValue = newSliderValue
        }
    }
}
