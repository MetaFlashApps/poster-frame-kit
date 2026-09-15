import Foundation

@main
struct PosterFrameKitQualityBenchmark {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(
                Data("Quality benchmark failed: \(error.localizedDescription)\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static func run() async throws {
        guard #available(macOS 15.0, *) else {
            throw QualityBenchmarkError.unsupportedOperatingSystem
        }

        let arguments = try QualityArguments.parse(
            Array(CommandLine.arguments.dropFirst())
        )
        let manifest = try QualityFixtureManifest.load(from: arguments.manifestURL)
        let repositoryRoot = arguments.manifestURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureDirectory = repositoryRoot.appending(
            path: manifest.outputDirectory
        )
        try FileManager.default.createDirectory(
            at: arguments.outputDirectory,
            withIntermediateDirectories: true
        )
        let selectedFixtures = try manifest.selectedCoreFixtures(
            fixtureIDs: arguments.fixtureIDs,
            includePendingReview: arguments.includePendingReview
        )

        var results: [QualityReport.FixtureResult] = []
        for fixture in selectedFixtures {
            let videoURL = try await QualityFixtureResolver.videoURL(
                for: fixture,
                in: fixtureDirectory
            )
            let result = try await QualityComparisonRunner.run(
                fixture: fixture,
                videoURL: videoURL,
                candidateCount: arguments.candidateCount,
                outputDirectory: arguments.outputDirectory,
                galleryDirectory: arguments.galleryDirectory,
                posterFramePolicy: arguments.posterFramePolicy,
                profileOverride: arguments.profileOverride,
                includesFaceCalibration: arguments.calibratesFaces,
                aestheticCandidateCount:
                    arguments.effectiveAestheticCandidateCount
            )
            results.append(result)
            print(
                "\(fixture.id): midpoint \(result.midpoint.timeSeconds)s, "
                    + "PosterFrameKit \(result.posterFrameKit.timeSeconds)s, "
                    + "Vision \(result.vision.timeSeconds)s, "
                    + "hybrid \(result.hybrid.timeSeconds)s"
            )
        }

        let report = QualityReport(
            schemaVersion: reportSchemaVersion(for: arguments),
            generatedAt: .now,
            system: .current,
            candidateCount: arguments.candidateCount,
            aestheticCandidateCount: arguments.aestheticCandidateCount,
            comparisonPolicy: comparisonPolicy(
                for: arguments.posterFramePolicy,
                profileOverride: arguments.profileOverride,
                aestheticCandidateCount:
                    arguments.effectiveAestheticCandidateCount
            ),
            fixtures: results
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let reportURL =
            arguments.reportURL
            ?? arguments.outputDirectory.appending(path: "report.json")
        try FileManager.default.createDirectory(
            at: reportURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(to: reportURL, options: .atomic)
        print("Wrote quality report to \(reportURL.path)")
    }

    private static func comparisonPolicy(
        for policy: QualityComparisonRunner.QualityPosterFramePolicy,
        profileOverride: QualityProfileOverride?,
        aestheticCandidateCount: Int
    ) -> String {
        let posterFramePolicy = switch policy {
        case .deterministic:
            "PosterFrameKit uses only the selected profile's deterministic metrics"
        case .visionFirst:
            "PosterFrameKit uses the selected profile, an enabled face preference with its eight-candidate default, and Vision-first aesthetic preference over at most \(aestheticCandidateCount) leading candidates"
        }
        let profilePolicy = profileOverride.map {
            "the command-line profile override \($0.rawValue) replaces each fixture's declared profile; "
        } ?? "each fixture uses its declared profile; "
        return "Midpoint decodes the fixed 50% position independently; "
            + profilePolicy
            + posterFramePolicy
            + "; Vision ranks all shared candidates by overallScore; hybrid equally blends normalized Vision and PosterFrameKit base scores."
    }

    private static func reportSchemaVersion(
        for arguments: QualityArguments
    ) -> Int {
        if arguments.aestheticCandidateCount != nil {
            return 5
        }
        return arguments.calibratesFaces ? 4 : 3
    }
}
