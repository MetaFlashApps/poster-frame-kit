import Darwin
import Foundation

struct SubtitleBenchmarkReport: Codable, Sendable {
  let schemaVersion: Int
  let generatedAt: Date
  let benchmarkIdentifier: String
  let source: SubtitleBenchmarkManifest.Source
  let environment: Environment
  let configuration: Configuration
  let summary: Summary
  let variantSummaries: [VariantSummary]
  let samples: [SampleResult]
  let notes: [String]

  struct Environment: Codable, Sendable {
    let hardwareModel: String
    let operatingSystem: String
    let architecture: String
    let processorCount: Int

    static var current: Self {
      Self(
        hardwareModel: systemString("hw.model") ?? "unknown",
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: architectureName,
        processorCount: ProcessInfo.processInfo.activeProcessorCount
      )
    }

    private static var architectureName: String {
      #if arch(arm64)
        "arm64"
      #elseif arch(x86_64)
        "x86_64"
      #else
        "unknown"
      #endif
    }

    private static func systemString(_ name: String) -> String? {
      var size = 0
      guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return nil
      }
      var value = [CChar](repeating: 0, count: size)
      guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
        return nil
      }
      let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
      return String(decoding: bytes, as: UTF8.self)
    }
  }

  struct Configuration: Codable, Sendable {
    let rendererVersion: Int
    let decisionRule: String
    let maximumFrameWidth: Int
    let maximumFrameHeight: Int
    let warmupCount: Int
    let imageOutput: String
  }

  struct Summary: Codable, Equatable, Sendable {
    let sampleCount: Int
    let evaluatedSampleCount: Int
    let ambiguousCount: Int
    let truePositiveCount: Int
    let falseNegativeCount: Int
    let trueNegativeCount: Int
    let falsePositiveCount: Int
    let accurateFallbackCount: Int
    let medianAnalysisMilliseconds: Double
    let recall: Double?
    let specificity: Double?

    init(samples: [SampleResult]) {
      sampleCount = samples.count
      evaluatedSampleCount = samples.count { $0.expectedDetection != nil }
      ambiguousCount = sampleCount - evaluatedSampleCount
      truePositiveCount = samples.count {
        $0.expectedDetection == true && $0.detected
      }
      falseNegativeCount = samples.count {
        $0.expectedDetection == true && !$0.detected
      }
      trueNegativeCount = samples.count {
        $0.expectedDetection == false && !$0.detected
      }
      falsePositiveCount = samples.count {
        $0.expectedDetection == false && $0.detected
      }
      accurateFallbackCount = samples.count(where: \.usedAccurateRecognition)
      recall = Self.ratio(
        truePositiveCount,
        truePositiveCount + falseNegativeCount
      )
      specificity = Self.ratio(
        trueNegativeCount,
        trueNegativeCount + falsePositiveCount
      )
      let timings = samples.map(\.analysisMilliseconds).sorted()
      if timings.isEmpty {
        medianAnalysisMilliseconds = 0
      } else if timings.count.isMultiple(of: 2) {
        let upper = timings.count / 2
        medianAnalysisMilliseconds = (timings[upper - 1] + timings[upper]) / 2
      } else {
        medianAnalysisMilliseconds = timings[timings.count / 2]
      }
    }

    private static func ratio(_ numerator: Int, _ denominator: Int) -> Double? {
      denominator == 0 ? nil : Double(numerator) / Double(denominator)
    }
  }

  struct VariantSummary: Codable, Sendable {
    let variantID: String
    let language: String?
    let style: SubtitleRenderStyle
    let summary: Summary
  }

  struct SampleResult: Codable, Sendable {
    let sampleID: String
    let variantID: String
    let language: String?
    let style: SubtitleRenderStyle
    let tags: [String]
    let requestedTimeSeconds: Double
    let actualTimeSeconds: Double
    let expectedDetection: Bool?
    let detected: Bool
    let likelihood: Double
    let usedAccurateRecognition: Bool
    let analysisMilliseconds: Double
    let heuristicSuspicious: Bool
    let heuristicTotalEdgeCount: Int
    let heuristicConcentration: Double
    let heuristicWindowDensity: Double
    let heuristicBrightStrokeCount: Int
    let heuristicBrightStrokeConcentration: Double
    let heuristicBrightStrokeWindowDensity: Double
    let accurateDiagnosticLikelihood: Double?
    let accurateDiagnosticMilliseconds: Double?
    let imagePath: String?
  }
}
