import SwiftUI

struct DemoResultsView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        VStack(spacing: 0) {
            DemoVideoSummaryView(viewModel: viewModel)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    DemoPreviewView(viewModel: viewModel)
                }
                .padding()
            }
        }
    }
}
