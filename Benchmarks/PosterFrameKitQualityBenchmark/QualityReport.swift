import Darwin
import Foundation

struct QualityReport: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let system: System
    let candidateCount: Int
    let aestheticCandidateCount: Int?
    let comparisonPolicy: String
    let fixtures: [FixtureResult]

    struct System: Codable {
        let operatingSystem: String
        let architecture: String
        let processor: String
        let processorCount: Int
        let physicalMemoryBytes: UInt64

        static var current: System {
            #if arch(arm64)
                let architecture = "arm64"
            #elseif arch(x86_64)
                let architecture = "x86_64"
            #else
                let architecture = "unknown"
            #endif
            return System(
                operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: architecture,
                processor: sysctlString("machdep.cpu.brand_string"),
                processorCount: ProcessInfo.processInfo.processorCount,
                physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
            )
        }

        private static func sysctlString(_ name: String) -> String {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
                return "unknown"
            }
            var value = [CChar](repeating: 0, count: size)
            guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
                return "unknown"
            }
            return String(
                decoding: value.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)),
                as: UTF8.self
            )
        }
    }

    struct FixtureResult: Codable {
        let id: String
        let profile: String
        let decodedCandidateCount: Int
        let captureMilliseconds: Double
        let visionAnalysisMilliseconds: Double
        let midpoint: Selection
        let posterFrameKit: Selection
        let vision: Selection
        let hybrid: Selection
        let faceCalibration: FaceCalibration?
    }

    struct Selection: Codable {
        let timeSeconds: Double
        let score: Double
        let acceptable: Bool?
        let imagePath: String
        let faceCompositionBonus: Double?
        let visionScore: Double?
        let posterFrameScore: Double?
        let isUtilityFrame: Bool?
    }

    struct FaceCalibration: Codable {
        let firstPassMilliseconds: Double
        let warmPassMilliseconds: Double
        let detectedCandidateCount: Int
        let scoredCandidateCount: Int
        let totalFaceCount: Int
        let detectionsStable: Bool
        let candidateCount: Int
        let maximumBonus: Double
        let baseWinnerTimeSeconds: Double
        let preferredWinnerTimeSeconds: Double
        let preferredWinnerCompositionQuality: Double
        let contactSheetPath: String
        let candidates: [FaceCandidate]
    }

    struct FaceCandidate: Codable {
        let baseRank: Int
        let timeSeconds: Double
        let baseScore: Double
        let faceCount: Int
        let compositionQuality: Double
        let firstPassMilliseconds: Double
        let warmPassMilliseconds: Double
        let faceBounds: [NormalizedBounds]
        let faceConfidences: [Float]
    }

    struct NormalizedBounds: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
}

extension Duration {
    var qualityMilliseconds: Double {
        let components = self.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
