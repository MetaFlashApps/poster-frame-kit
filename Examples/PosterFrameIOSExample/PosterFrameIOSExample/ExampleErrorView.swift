import PhotosUI
import SwiftUI

struct ExampleErrorView: View {
  let fileName: String?
  let message: String
  @Binding var selectedPhoto: PhotosPickerItem?
  let chooseFile: () -> Void

  var body: some View {
    VStack {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("Selection Failed")
        .font(.title2)
        .bold()

      if let fileName {
        Text(fileName)
          .bold()
      }

      Text(message)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      PhotosPicker(
        selection: $selectedPhoto,
        matching: .videos,
        preferredItemEncoding: .current
      ) {
        Label("Choose Another Video", systemImage: "photo.on.rectangle")
      }
        .buttonStyle(.borderedProminent)

      Button("Choose from Files", systemImage: "folder", action: chooseFile)
    }
    .padding()
  }
}
