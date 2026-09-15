import Foundation
import PosterFrameKit

struct BenchmarkReport: Codable {
  let schemaVersion: Int
  let label: String
  let generatedAt: String
  let system: BenchmarkSystem
  let fixture: BenchmarkFixtureDescription
  let configuration: BenchmarkConfiguration
  let measurements: [LaneMeasurement]
  let notes: [String]
}

struct BenchmarkSystem: Codable {
  let chip: String
  let logicalCoreCount: Int
  let memoryBytes: UInt64
  let operatingSystem: String
  let architecture: String

  static func current() -> BenchmarkSystem {
    BenchmarkSystem(
      chip: sysctlString("machdep.cpu.brand_string") ?? "unknown",
      logicalCoreCount: ProcessInfo.processInfo.activeProcessorCount,
      memoryBytes: UInt64(ProcessInfo.processInfo.physicalMemory),
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: currentArchitecture
    )
  }
}

struct BenchmarkFixtureDescription: Codable {
  let identifier: String
  let codec: String
  let width: Int
  let height: Int
  let framesPerSecond: Int
  let durationSeconds: Double
  let generated: Bool
}

struct BenchmarkConfiguration: Codable {
  let profile: String
  let candidateCount: Int
  let searchRange: [Double]
  let excludedRanges: [[Double]]
  let outputWidth: Int
  let outputHeight: Int
  let exactTimeTolerance: Bool
  let avoidsSubtitles: Bool
  let subtitleCandidateCount: Int?
  let subtitleMaximumPenalty: Double?
  let prefersFaces: Bool
  let faceCandidateCount: Int?
  let faceMaximumBonus: Double?
  let prefersAesthetics: Bool
  let aestheticCandidateCount: Int?
  let aestheticMaximumAdjustment: Double?
  let residentMemorySamplingIntervalMilliseconds: Int
}

struct LaneMeasurement: Codable {
  let decoderLaneCount: Int
  let processColdRuns: [WorkerMeasurement]
  let processWarmRuns: [WorkerMeasurement]
  let processColdMedianMilliseconds: Double
  let processWarmMedianMilliseconds: Double
  let processColdMedianPeakResidentBytes: UInt64
  let processWarmMedianPeakResidentBytes: UInt64
  let processColdMedianPeakResidentIncreaseBytes: UInt64
  let processWarmMedianPeakResidentIncreaseBytes: UInt64
}

struct WorkerMeasurement: Codable {
  let endToEndMilliseconds: Double
  let selectedTimeSeconds: Double
  let score: Double
  let adjustedScore: Double
  let subtitlePenalty: Double
  let faceCompositionBonus: Double
  let aestheticScore: Double?
  let isUtilityFrame: Bool?
  let aestheticAdjustment: Double
  let memory: SelectionMemoryMeasurement
  let performance: PosterFramePerformanceSnapshot
}

struct SelectionMemoryMeasurement: Codable {
  let startingResidentBytes: UInt64
  let sampledPeakResidentBytes: UInt64
  let endingResidentBytes: UInt64
  let peakResidentIncreaseBytes: UInt64
}
