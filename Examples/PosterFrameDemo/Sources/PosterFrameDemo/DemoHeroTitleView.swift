import SwiftUI

struct DemoHeroTitleView: View {
    let title: String
    let isRecommendation: Bool
    var showsStatus = true

    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .bold()

            if showsStatus {
                Text(isRecommendation ? "Recommendation" : "Browsing")
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(
                        isRecommendation ? Color.green : Color.accentColor
                    )
                    .background(
                        (isRecommendation ? Color.green : Color.accentColor)
                            .opacity(0.14),
                        in: .capsule
                    )
            }
        }
    }
}
