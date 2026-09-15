import CoreGraphics
import SwiftUI

struct DemoFrameSurface: View {
    let image: CGImage?
    let accessibilityLabel: String
    let emptyTitle: String
    let emptyDescription: String
    let isWorking: Bool
    let workingDescription: String
    var isUpdating = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)

            if let image {
                Image(
                    image,
                    scale: 1,
                    orientation: .up,
                    label: Text(accessibilityLabel)
                )
                .resizable()
                .scaledToFit()
                .opacity(isUpdating ? 0.72 : 1)
            } else if isWorking {
                DemoLoadingIndicator(accessibilityLabel: workingDescription)
            } else {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "film",
                    description: Text(emptyDescription)
                )
                .foregroundStyle(.secondary)
            }

            if isUpdating, image != nil {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.black.opacity(0.24))
                DemoLoadingIndicator(accessibilityLabel: workingDescription)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(.rect(cornerRadius: 14))
    }
}
