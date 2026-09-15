import Foundation

struct SubtitleCue: Equatable, Sendable {
  let startSeconds: Double
  let endSeconds: Double
  let lines: [String]

  func contains(_ time: Double) -> Bool {
    time >= startSeconds && time < endSeconds
  }
}

enum SRTParser {
  static func parse(data: Data) throws -> [SubtitleCue] {
    guard let string = String(data: data, encoding: .utf8) else {
      throw SubtitleBenchmarkError.invalidSubtitle("SRT must be UTF-8")
    }
    return try parse(string: string)
  }

  static func parse(string: String) throws -> [SubtitleCue] {
    let normalized = string
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      throw SubtitleBenchmarkError.invalidSubtitle("SRT is empty")
    }

    return try normalized.components(separatedBy: "\n\n").map { block in
      let lines = block.components(separatedBy: "\n")
      let timingIndex = lines.firstIndex(where: { $0.contains(" --> ") })
      guard let timingIndex else {
        throw SubtitleBenchmarkError.invalidSubtitle(
          "SRT block has no timing line"
        )
      }
      let bounds = lines[timingIndex].components(separatedBy: " --> ")
      guard bounds.count == 2 else {
        throw SubtitleBenchmarkError.invalidSubtitle(
          "SRT timing line is malformed"
        )
      }
      let start = try timestamp(bounds[0])
      let end = try timestamp(bounds[1])
      let text = lines.dropFirst(timingIndex + 1).filter { !$0.isEmpty }
      guard end > start, !text.isEmpty else {
        throw SubtitleBenchmarkError.invalidSubtitle(
          "SRT cue must have ascending times and text"
        )
      }
      return SubtitleCue(
        startSeconds: start,
        endSeconds: end,
        lines: text
      )
    }
  }

  static func cue(at time: Double, in cues: [SubtitleCue]) -> SubtitleCue? {
    cues.first { $0.contains(time) }
  }

  private static func timestamp(_ value: String) throws -> Double {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    let fields = trimmed.components(separatedBy: ":")
    guard fields.count == 3,
      let hours = Double(fields[0]),
      let minutes = Double(fields[1])
    else {
      throw SubtitleBenchmarkError.invalidSubtitle(
        "Invalid SRT timestamp: \(trimmed)"
      )
    }
    let secondsField = fields[2].replacingOccurrences(of: ",", with: ".")
    guard let seconds = Double(secondsField),
      hours >= 0, minutes >= 0, minutes < 60,
      seconds >= 0, seconds < 60
    else {
      throw SubtitleBenchmarkError.invalidSubtitle(
        "Invalid SRT timestamp: \(trimmed)"
      )
    }
    return hours * 3_600 + minutes * 60 + seconds
  }
}
