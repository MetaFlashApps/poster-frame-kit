import SwiftUI

struct DemoAnalyticsMethodologyView: View {
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(
                        "PosterFrameKit measures its optimized URL path from duration loading through the selected frame."
                    )
                } icon: {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.tint)
                }

                Label {
                    Text(
                        "The Vision workflow combines a separate deterministic candidate capture with Apple Vision's ranking time."
                    )
                } icon: {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.purple)
                }

                Label {
                    Text(
                        "The headline compares complete workflows in this demo. It is not a claim that PosterFrameKit's ranker alone is faster than the raw Vision request."
                    )
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label("Measurement Scope", systemImage: "ruler")
        }
    }
}
