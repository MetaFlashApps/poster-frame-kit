import PosterFrameKit
import SwiftUI

struct DemoRefinementBreakdownView: View {
    let result: PosterFrameResult
    let options: PosterFrameOptions?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                DemoScoreComponentRow(
                    title: "Base Quality Score",
                    systemImage: "slider.horizontal.3",
                    value: result.score,
                    tint: .primary,
                    isSigned: false
                )

                if options?.facePreference != nil {
                    DemoScoreComponentRow(
                        title: "Face Composition Bonus",
                        systemImage: "face.smiling",
                        value: result.faceCompositionBonus,
                        tint: .green,
                        isSigned: true
                    )
                }

                if options?.subtitleAvoidance != nil {
                    DemoScoreComponentRow(
                        title: "Subtitle Penalty",
                        systemImage: "captions.bubble.fill",
                        value: -result.subtitlePenalty,
                        tint: .orange,
                        isSigned: true
                    )
                }

                if options?.aestheticPreference != nil {
                    DemoScoreComponentRow(
                        title: "Aesthetic Adjustment",
                        systemImage: "sparkles",
                        value: result.aestheticAdjustment,
                        tint: .purple,
                        isSigned: true
                    )

                    LabeledContent("Vision Aesthetic Score") {
                        if let aestheticScore = result.aestheticScore {
                            Text(
                                aestheticScore,
                                format: .number
                                    .sign(strategy: .always())
                                    .precision(.fractionLength(3))
                            )
                            .monospacedDigit()
                        } else {
                            Text("Unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Vision Classification") {
                        if let isUtilityFrame = result.isUtilityFrame {
                            Text(isUtilityFrame ? "Utility frame" : "Not utility")
                        } else {
                            Text("Unavailable")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                DemoScoreComponentRow(
                    title: "Final Ranking Score",
                    systemImage: "equal.circle.fill",
                    value: result.adjustedScore,
                    tint: .accentColor,
                    isSigned: false
                )

            }
        } label: {
            Label("Ranking Breakdown", systemImage: "sum")
        }
    }
}
