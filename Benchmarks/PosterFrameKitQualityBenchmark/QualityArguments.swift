import Foundation
import PosterFrameKit

struct QualityArguments {
    var manifestURL = URL(fileURLWithPath: "Benchmarks/Fixtures/manifest.json")
    var outputDirectory = URL(fileURLWithPath: "Benchmarks/.quality-results")
    var galleryDirectory: URL?
    var reportURL: URL?
    var candidateCount = 24
    var fixtureIDs: Set<String> = []
    var includePendingReview = false
    var usesDeterministicPosterFramePolicy = false
    var calibratesFaces = false
    var aestheticCandidateCount: Int?
    var profileOverride: QualityProfileOverride?

    static func parse(_ values: [String]) throws -> QualityArguments {
        var result = QualityArguments()
        var index = 0
        while index < values.count {
            let argument = values[index]
            switch argument {
            case "--manifest":
                index += 1
                result.manifestURL = try fileURL(after: argument, in: values, at: index)
            case "--output-directory":
                index += 1
                result.outputDirectory = try fileURL(after: argument, in: values, at: index)
            case "--gallery-directory":
                index += 1
                result.galleryDirectory = try fileURL(
                    after: argument,
                    in: values,
                    at: index
                )
            case "--report":
                index += 1
                result.reportURL = try fileURL(after: argument, in: values, at: index)
            case "--candidates":
                index += 1
                guard index < values.count,
                    let count = Int(values[index]),
                    count > 0
                else {
                    throw QualityBenchmarkError.invalidArguments(
                        "--candidates requires a positive integer"
                    )
                }
                result.candidateCount = count
            case "--fixture":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw QualityBenchmarkError.invalidArguments(
                        "--fixture requires an identifier"
                    )
                }
                result.fixtureIDs.insert(values[index])
            case "--include-pending-review":
                result.includePendingReview = true
            case "--deterministic-posterframe":
                result.usesDeterministicPosterFramePolicy = true
            case "--calibrate-faces":
                result.calibratesFaces = true
            case "--aesthetic-candidates":
                index += 1
                guard index < values.count,
                    let count = Int(values[index]),
                    count > 0
                else {
                    throw QualityBenchmarkError.invalidArguments(
                        "--aesthetic-candidates requires a positive integer"
                    )
                }
                result.aestheticCandidateCount = count
            case "--profile":
                index += 1
                guard index < values.count,
                    let profile = QualityProfileOverride(rawValue: values[index])
                else {
                    throw QualityBenchmarkError.invalidArguments(
                        "--profile requires general or animation"
                    )
                }
                result.profileOverride = profile
            default:
                throw QualityBenchmarkError.invalidArguments(
                    "Unknown argument: \(argument)"
                )
            }
            index += 1
        }
        guard !result.calibratesFaces
            || result.usesDeterministicPosterFramePolicy
        else {
            throw QualityBenchmarkError.invalidArguments(
                "--calibrate-faces requires --deterministic-posterframe"
            )
        }
        guard result.aestheticCandidateCount == nil
            || !result.usesDeterministicPosterFramePolicy
        else {
            throw QualityBenchmarkError.invalidArguments(
                "--aesthetic-candidates requires Vision-first PosterFrameKit"
            )
        }
        if let aestheticCandidateCount = result.aestheticCandidateCount,
            aestheticCandidateCount > result.candidateCount
        {
            throw QualityBenchmarkError.invalidArguments(
                "--aesthetic-candidates must not exceed --candidates"
            )
        }
        return result
    }

    private static func fileURL(
        after argument: String,
        in values: [String],
        at index: Int
    ) throws -> URL {
        guard index < values.count else {
            throw QualityBenchmarkError.invalidArguments(
                "\(argument) requires a path"
            )
        }
        return URL(fileURLWithPath: values[index])
    }
}

enum QualityProfileOverride: String, CaseIterable, Sendable {
    case general
    case animation

    var profile: PosterFrameProfile {
        switch self {
        case .general: .general
        case .animation: .animation
        }
    }
}

extension QualityArguments {
    var posterFramePolicy: QualityComparisonRunner.QualityPosterFramePolicy {
        usesDeterministicPosterFramePolicy ? .deterministic : .visionFirst
    }

    var effectiveAestheticCandidateCount: Int {
        aestheticCandidateCount ?? PosterFrameAestheticOptions().candidateCount
    }
}

enum QualityBenchmarkError: Error, LocalizedError {
    case invalidArguments(String)
    case invalidManifest(String)
    case unsupportedOperatingSystem
    case noCandidates
    case imageCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message), .invalidManifest(let message):
            message
        case .unsupportedOperatingSystem:
            "Quality comparison requires macOS 15 or newer."
        case .noCandidates:
            "The candidate plan produced no decoded frames."
        case .imageCreationFailed:
            "A selected candidate image could not be created."
        }
    }
}
