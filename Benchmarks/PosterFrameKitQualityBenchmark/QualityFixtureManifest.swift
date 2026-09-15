import Foundation
import PosterFrameKit
import PosterFrameKitBenchmarkSupport

struct QualityFixtureManifest: Decodable {
    let schemaVersion: Int
    let outputDirectory: String
    let fixtures: [Fixture]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case outputDirectory
        case fixtures
    }

    struct Fixture: Decodable {
        enum Kind: String, Decodable {
            case downloaded
            case generated
        }

        let id: String
        let kind: Kind
        let status: String
        let tier: String
        let generator: Generator?
        let outputFileName: String?
        let expectations: Expectations

        struct Generator: Decodable {
            let name: String
            let version: Int
            let variant: String
            let identifier: String
            let width: Int
            let height: Int
            let framesPerSecond: Int
            let durationSeconds: Int
            let maximumKeyFrameInterval: Int
        }

        struct Expectations: Decodable {
            let profile: String
            let reviewStatus: String
            let acceptableTimeRanges: [[Double]]
        }

        var profile: PosterFrameProfile {
            switch expectations.profile {
            case "animation": .animation
            default: .general
            }
        }

        var acceptableRanges: [ClosedRange<Double>] {
            expectations.acceptableTimeRanges.compactMap { bounds in
                guard bounds.count == 2, bounds[0] <= bounds[1] else {
                    return nil
                }
                return bounds[0]...bounds[1]
            }
        }

        func generatedVariant() throws -> GeneratedFixtureVariant {
            guard kind == .generated, let generator else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(id) has no generated definition"
                )
            }
            guard generator.name == GeneratedFixture.generatorName,
                let variant = GeneratedFixtureVariant(rawValue: generator.variant)
            else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(id) uses an unsupported generator"
                )
            }
            let definition = variant.definition
            guard generator.version == definition.version,
                generator.identifier == definition.identifier,
                generator.width == definition.width,
                generator.height == definition.height,
                generator.framesPerSecond == definition.framesPerSecond,
                generator.durationSeconds == definition.durationSeconds,
                generator.maximumKeyFrameInterval == definition.maximumKeyFrameInterval
            else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(id) generator metadata does not match \(generator.variant)"
                )
            }
            return variant
        }
    }

    static func load(from url: URL) throws -> QualityFixtureManifest {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        guard manifest.schemaVersion == 2 else {
            throw QualityBenchmarkError.invalidManifest(
                "Quality fixture schemaVersion must be 2"
            )
        }
        guard !manifest.outputDirectory.isEmpty else {
            throw QualityBenchmarkError.invalidManifest(
                "outputDirectory must not be empty"
            )
        }
        guard Set(manifest.fixtures.map(\.id)).count == manifest.fixtures.count else {
            throw QualityBenchmarkError.invalidManifest(
                "Fixture identifiers must be unique"
            )
        }
        for fixture in manifest.fixtures {
            guard ["general", "animation"].contains(fixture.expectations.profile)
            else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(fixture.id) has an unsupported profile"
                )
            }
            guard [
                "initial-human-review", "pending-human-review", "deferred",
            ].contains(fixture.expectations.reviewStatus) else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(fixture.id) has an unsupported review status"
                )
            }
            guard fixture.expectations.acceptableTimeRanges.allSatisfy({ bounds in
                bounds.count == 2 && bounds[0] >= 0 && bounds[0] <= bounds[1]
            }) else {
                throw QualityBenchmarkError.invalidManifest(
                    "Fixture \(fixture.id) has an invalid acceptable time range"
                )
            }
            if fixture.expectations.reviewStatus == "pending-human-review",
                !fixture.expectations.acceptableTimeRanges.isEmpty
            {
                throw QualityBenchmarkError.invalidManifest(
                    "Pending fixture \(fixture.id) cannot declare reviewed ranges"
                )
            }
            if fixture.status == "active",
                fixture.expectations.reviewStatus == "initial-human-review",
                fixture.expectations.acceptableTimeRanges.isEmpty
            {
                throw QualityBenchmarkError.invalidManifest(
                    "Reviewed fixture \(fixture.id) requires acceptable ranges"
                )
            }
            guard fixture.status == "active" else {
                continue
            }
            guard let outputFileName = fixture.outputFileName,
                URL(fileURLWithPath: outputFileName).lastPathComponent == outputFileName,
                outputFileName.hasSuffix(".mp4")
            else {
                throw QualityBenchmarkError.invalidManifest(
                    "Active fixture \(fixture.id) requires a plain MP4 output name"
                )
            }
            if fixture.kind == .generated {
                _ = try fixture.generatedVariant()
            } else if fixture.generator != nil {
                throw QualityBenchmarkError.invalidManifest(
                    "Downloaded fixture \(fixture.id) cannot declare a generator"
                )
            }
        }
        return manifest
    }

    func selectedCoreFixtures(
        fixtureIDs: Set<String>,
        includePendingReview: Bool
    ) throws -> [Fixture] {
        let activeCoreFixtures = fixtures.filter {
            $0.status == "active" && $0.tier == "core"
        }
        if !fixtureIDs.isEmpty {
            let availableIDs = Set(activeCoreFixtures.map(\.id))
            let unavailableIDs = fixtureIDs.subtracting(availableIDs).sorted()
            guard unavailableIDs.isEmpty else {
                throw QualityBenchmarkError.invalidArguments(
                    "Unknown active core fixture: \(unavailableIDs.joined(separator: ", "))"
                )
            }
            return activeCoreFixtures.filter { fixtureIDs.contains($0.id) }
        }
        guard !includePendingReview else {
            return activeCoreFixtures
        }
        return activeCoreFixtures.filter {
            $0.expectations.reviewStatus != "pending-human-review"
        }
    }
}
