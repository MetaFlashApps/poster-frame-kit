import SwiftUI

struct ExampleLoadingView: View {
  let fileName: String

  var body: some View {
    VStack {
      ProgressView()
        .controlSize(.large)
        .accessibilityLabel("Selecting poster frame")

      Text("Selecting Poster Frame")
        .font(.headline)

      Text(fileName)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}
