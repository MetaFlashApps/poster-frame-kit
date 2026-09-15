import SwiftUI

struct DemoSettingsToggleButton: View {
    let kind: DemoPreferenceKind
    @Binding var isOn: Bool
    let showsTitle: Bool
    var isEnabled = true

    var body: some View {
        Toggle(isOn: $isOn) {
            if showsTitle {
                Label(kind.title, systemImage: kind.systemImage)
            } else {
                Image(systemName: kind.systemImage)
            }
        }
        .toggleStyle(.button)
        .tint(.accentColor)
        .disabled(!isEnabled)
        .fixedSize()
        .help(kind.helpText)
        .accessibilityLabel(kind.title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
