import SwiftUI

struct DemoPreviewView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DemoHeroResultView(viewModel: viewModel)

            if viewModel.selectedURL != nil {
                DemoCandidateBrowserView(viewModel: viewModel)

                Label("Comparisons", systemImage: "rectangle.3.group")
                    .font(.title2)
                    .bold()

                DemoComparisonGridView(viewModel: viewModel)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
