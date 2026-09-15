import SwiftUI

struct DemoLoadingIndicator: View {
  let accessibilityLabel: String

  var body: some View {
    ProgressView()
      .progressViewStyle(.circular)
      .controlSize(.large)
      .tint(.white)
      .labelsHidden()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}
