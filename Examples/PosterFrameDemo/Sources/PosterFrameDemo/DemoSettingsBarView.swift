import SwiftUI

struct DemoSettingsBarView: View {
    @Bindable var viewModel: DemoViewModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            DemoSettingsWideView(viewModel: viewModel)
            DemoSettingsCompactView(viewModel: viewModel)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
