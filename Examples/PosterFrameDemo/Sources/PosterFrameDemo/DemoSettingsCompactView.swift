import SwiftUI

struct DemoSettingsCompactView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        HStack(spacing: 8) {
            Stepper(
                value: $viewModel.maximumFramesExamined,
                in: 8...80,
                step: 8
            ) {
                Label(
                    "\(viewModel.maximumFramesExamined) candidates",
                    systemImage: "rectangle.stack"
                )
                .monospacedDigit()
            }
            .fixedSize()
            .help("Number of video frames PosterFrameKit may examine.")

            Spacer(minLength: 4)

            ForEach(DemoPreferenceKind.allCases) { kind in
                DemoSettingsPreferenceToggle(
                    viewModel: viewModel,
                    kind: kind,
                    showsTitle: false
                )
            }
        }
        .controlSize(.small)
    }
}
