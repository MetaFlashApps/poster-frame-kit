import SwiftUI

struct DemoSettingsWideView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        HStack(spacing: 12) {
            DemoCandidateCountControl(
                value: $viewModel.maximumFramesExamined
            )
            .frame(width: 250)

            ForEach(DemoPreferenceKind.allCases) { kind in
                DemoSettingsPreferenceToggle(
                    viewModel: viewModel,
                    kind: kind,
                    showsTitle: true
                )
            }
        }
        .controlSize(.small)
        .fixedSize(horizontal: true, vertical: false)
    }
}
