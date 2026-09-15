import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ExampleContentView: View {
  @StateObject private var viewModel = ExampleViewModel()
  @State private var selectedPhoto: PhotosPickerItem?
  @State private var isFileImporterPresented = false

  var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle:
          ExampleIdleView(
            selectedPhoto: $selectedPhoto,
            chooseFile: chooseFile
          )
        case .loading(let fileName):
          ExampleLoadingView(fileName: fileName)
        case .success(let fileName, let selection):
          ExampleResultView(fileName: fileName, selection: selection)
        case .failure(let fileName, let message):
          ExampleErrorView(
            fileName: fileName,
            message: message,
            selectedPhoto: $selectedPhoto,
            chooseFile: chooseFile
          )
        }
      }
      .navigationTitle("PosterFrameKit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          PhotosPicker(
            selection: $selectedPhoto,
            matching: .videos,
            preferredItemEncoding: .current
          ) {
            Label("Choose from Photos", systemImage: "photo.on.rectangle")
          }

          Menu("More Video Sources", systemImage: "ellipsis.circle") {
            Button("Choose from Files", systemImage: "folder", action: chooseFile)
          }
        }
      }
    }
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: [.movie]
    ) { result in
      viewModel.handleFileImport(result)
    }
    .task(id: selectedPhoto) {
      guard let photo = selectedPhoto else {
        return
      }
      await viewModel.handlePhotoImport(photo)
      if selectedPhoto == photo {
        selectedPhoto = nil
      }
    }
  }

  private func chooseFile() {
    isFileImporterPresented = true
  }
}

#Preview {
  ExampleContentView()
}
