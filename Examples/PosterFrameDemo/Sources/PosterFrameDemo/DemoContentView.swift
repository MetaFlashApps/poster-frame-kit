import SwiftUI
import UniformTypeIdentifiers

struct DemoContentView: View {
    @State private var viewModel = DemoViewModel()
    @State private var isImporterPresented = false
    @State private var selectedSection = DemoSection.results

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            DemoVideoControlsView(
                viewModel: viewModel,
                chooseVideo: presentImporter
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)

            Divider()

            Group {
                switch selectedSection {
                case .results:
                    DemoResultsView(viewModel: viewModel)
                case .metrics:
                    DemoMetricsView(viewModel: viewModel)
                case .analytics:
                    DemoAnalyticsView(viewModel: viewModel)
                }
            }

            Divider()
            DemoSettingsBarView(viewModel: viewModel)
            Divider()
            DemoBottomNavigationView(selection: $selectedSection)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .frame(minWidth: 500, minHeight: 520)
        .onChange(of: viewModel.options) { _, _ in
            viewModel.scheduleComparison()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .alert(
            "Operation Failed",
            isPresented: $viewModel.isShowingError
        ) {
            Button("OK", role: .cancel, action: viewModel.dismissError)
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private func presentImporter() {
        isImporterPresented = true
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }
            viewModel.selectVideo(url)
        case .failure(let error):
            viewModel.present(error)
        }
    }
}

#Preview {
    DemoContentView()
}
