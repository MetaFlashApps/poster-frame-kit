import CoreMedia
import Foundation

enum ExampleTimestampFormatter {
  private static let style = Duration.TimeFormatStyle(
    pattern: .hourMinuteSecond(
      padHourToLength: 2,
      fractionalSecondsLength: 3
    ),
    locale: Locale(identifier: "en_US_POSIX")
  )

  static func string(from time: CMTime) -> String? {
    guard time.isValid, time.isNumeric, time.seconds.isFinite else {
      return nil
    }
    return Duration.seconds(time.seconds).formatted(style)
  }
}
