import SwiftUI

struct DemoSettingsPreferenceToggle: View {
    @Bindable var viewModel: DemoViewModel
    let kind: DemoPreferenceKind
    let showsTitle: Bool

    var body: some View {
        switch kind {
        case .midrollExclusion:
            DemoSettingsToggleButton(
                kind: kind,
                isOn: $viewModel.excludesMidroll,
                showsTitle: showsTitle
            )
        case .subtitleAvoidance:
            DemoSettingsToggleButton(
                kind: kind,
                isOn: $viewModel.avoidsSubtitles,
                showsTitle: showsTitle
            )
        case .facePreference:
            DemoSettingsToggleButton(
                kind: kind,
                isOn: $viewModel.prefersFaces,
                showsTitle: showsTitle
            )
        case .aestheticPreference:
            DemoSettingsToggleButton(
                kind: kind,
                isOn: $viewModel.prefersAesthetics,
                showsTitle: showsTitle,
                isEnabled: viewModel.isVisionAvailable
            )
        }
    }
}
