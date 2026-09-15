import SwiftUI

struct DemoCandidateStripView: View {
    private static let fittedCandidateLimit = 32
    private static let barSpacing = 4.0
    private static let plotHeight = 58.0

    let candidates: [DemoCandidateFrame]
    let expectedCount: Int
    let officialCandidateID: DemoCandidateFrame.ID?
    let browsedCandidateID: DemoCandidateFrame.ID?
    let isUpdating: Bool
    let selectCandidate: (DemoCandidateFrame.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowSkeleton {
                ScrollView(.horizontal) {
                    LazyHStack(
                        alignment: .bottom,
                        spacing: Self.barSpacing
                    ) {
                        ForEach(0..<expectedCount, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.quaternary)
                                .frame(height: skeletonHeight(for: index))
                                .containerRelativeFrame(
                                    .horizontal,
                                    count: fittedSlotCount(for: expectedCount),
                                    span: 1,
                                    spacing: Self.barSpacing
                                )
                        }
                    }
                }
                .scrollDisabled(!shouldScroll(count: expectedCount))
                .scrollIndicators(
                    shouldScroll(count: expectedCount) ? .visible : .hidden
                )
                .frame(height: Self.plotHeight, alignment: .bottom)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Updating \(expectedCount) candidates")
            } else if candidates.isEmpty {
                ContentUnavailableView(
                    "No Candidates Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Choose a video to inspect its candidate scores.")
                )
                .frame(maxWidth: .infinity, minHeight: Self.plotHeight)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(
                        alignment: .bottom,
                        spacing: Self.barSpacing
                    ) {
                        ForEach(candidates) { candidate in
                            Button {
                                selectCandidate(candidate.id)
                            } label: {
                                DemoCandidateBarView(
                                    candidate: candidate,
                                    position: candidate.id + 1,
                                    totalCount: candidates.count,
                                    isRecommendation: candidate.id
                                        == officialCandidateID,
                                    isBrowsed: candidate.id
                                        == browsedCandidateID
                                )
                            }
                            .buttonStyle(.plain)
                            .containerRelativeFrame(
                                .horizontal,
                                count: fittedSlotCount(for: candidates.count),
                                span: 1,
                                spacing: Self.barSpacing
                            )
                            .help(helpText(for: candidate))
                        }
                    }
                }
                .scrollDisabled(!shouldScroll(count: candidates.count))
                .scrollIndicators(
                    shouldScroll(count: candidates.count) ? .visible : .hidden
                )
                .frame(height: Self.plotHeight)
            }

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var shouldShowSkeleton: Bool {
        isUpdating && candidates.count != expectedCount
    }

    private var summary: String {
        guard !candidates.isEmpty else {
            return "Candidate heights show PosterFrameKit base scores."
        }
        return "\(candidates.count) decoded candidates · select a bar to inspect its frame"
    }

    private func skeletonHeight(for index: Int) -> Double {
        10 + Double((index * 17) % 38)
    }

    private func shouldScroll(count: Int) -> Bool {
        count > Self.fittedCandidateLimit
    }

    private func fittedSlotCount(for count: Int) -> Int {
        min(max(1, count), Self.fittedCandidateLimit)
    }

    private func helpText(for candidate: DemoCandidateFrame) -> String {
        let timestamp = DemoTimestampFormatter.string(from: candidate.time)
            ?? "Unavailable"
        let metrics = candidate.metrics
        let brightness = formatted(metrics.meanLuma)
        let contrast = formatted(metrics.lumaDeviation)
        let entropy = formatted(metrics.entropy)
        let sharpness = formatted(metrics.sharpness)
        let color = formatted(metrics.colorfulness)
        let noise = formatted(metrics.visualNoise)
        return """
            \(timestamp) · Base score \(formatted(candidate.baseScore))
            Brightness \(brightness) · Contrast \(contrast) · Entropy \(entropy)
            Sharpness \(sharpness) · Color \(color) · Noise \(noise)
            """
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(3)))
    }
}
