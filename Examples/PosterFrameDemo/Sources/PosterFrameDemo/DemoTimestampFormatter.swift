import CoreMedia
import Foundation

enum DemoTimestampFormatter {
    private static let style = Duration.TimeFormatStyle(
        pattern: .hourMinuteSecond(
            padHourToLength: 2,
            fractionalSecondsLength: 3
        ),
        locale: Locale(identifier: "en_US_POSIX")
    )

    static func string(from time: CMTime) -> String? {
        guard time.isValid, time.isNumeric else {
            return nil
        }
        return string(from: time.seconds)
    }

    static func string(from seconds: Double) -> String? {
        guard seconds.isFinite else {
            return nil
        }
        return Duration.seconds(seconds).formatted(style)
    }
}
