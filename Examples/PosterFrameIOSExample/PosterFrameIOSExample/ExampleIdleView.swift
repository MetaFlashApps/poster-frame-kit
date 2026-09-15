import PhotosUI
import SwiftUI

struct ExampleIdleView: View {
  @Binding var selectedPhoto: PhotosPickerItem?
  let chooseFile: () -> Void

  var body: some View {
    VStack {
      Image(systemName: "photo.on.rectangle.angled")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("Choose a Video")
        .font(.title2)
        .bold()

      Text("PosterFrameKit will select a strong poster frame automatically.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      PhotosPicker(
        selection: $selectedPhoto,
        matching: .videos,
        preferredItemEncoding: .current
      ) {
        Label("Choose from Photos", systemImage: "photo.on.rectangle")
      }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

      Button("Choose from Files", systemImage: "folder", action: chooseFile)
    }
    .padding()
  }
}
