import SwiftUI

struct DemoVideoControlsView: View {
    @Bindable var viewModel: DemoViewModel
    let chooseVideo: () -> Void

    private var canCancel: Bool {
        viewModel.isAnalyzing || viewModel.isAutoRunPending
    }

    var body: some View {
        HStack {
            Button(
                "Video…",
                systemImage: "film",
                action: chooseVideo
            )
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered)
            .keyboardShortcut("o", modifiers: .command)

            Picker("Profile", selection: $viewModel.profile) {
                ForEach(DemoProfile.allCases) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            Button(
                "Refresh Analysis",
                systemImage: "arrow.clockwise",
                action: viewModel.runComparison
            )
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canRunAnalysis)
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh analysis")

            Button(
                "Cancel Analysis",
                systemImage: "xmark",
                action: viewModel.cancelAnalysis
            )
            .labelStyle(.iconOnly)
            .opacity(canCancel ? 1 : 0)
            .disabled(!canCancel)
            .accessibilityHidden(!canCancel)
            .help("Cancel analysis")
        }
    }
}
