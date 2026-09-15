import CoreMedia
import Foundation

struct CandidatePlanner {
    private static let preferredTimescale: CMTimeScale = 600

    static func timestamps(
        duration: CMTime,
        options: PosterFrameOptions
    ) throws -> [CMTime] {
        let durationInSeconds = duration.seconds
        guard duration.isValid,
              duration.isNumeric,
              durationInSeconds.isFinite,
              durationInSeconds > 0
        else {
            throw PosterFrameError.invalidDuration
        }

        let range = options.searchRange
        if range.lowerBound == range.upperBound {
            return [time(at: range.lowerBound, duration: durationInSeconds)]
        }

        if options.maximumFramesExamined == 1 {
            let midpoint = range.lowerBound + ((range.upperBound - range.lowerBound) / 2)
            let position = options.excludedRanges.contains(where: { $0.contains(midpoint) })
                ? fallbackPosition(options: options)
                : midpoint
            return [time(at: position, duration: durationInSeconds)]
        }

        let denominator = Double(options.maximumFramesExamined - 1)
        let positions = (0..<options.maximumFramesExamined).compactMap { index in
            let progress = Double(index) / denominator
            let position = range.lowerBound
                + ((range.upperBound - range.lowerBound) * progress)
            return options.excludedRanges.contains(where: { $0.contains(position) })
                ? nil
                : position
        }
        let usablePositions = positions.isEmpty
            ? [fallbackPosition(options: options)]
            : positions
        return usablePositions.map { time(at: $0, duration: durationInSeconds) }
    }

    private static func fallbackPosition(options: PosterFrameOptions) -> Double {
        var segments = [options.searchRange]

        for exclusion in options.excludedRanges {
            segments = segments.flatMap { segment in
                guard exclusion.upperBound >= segment.lowerBound,
                      exclusion.lowerBound <= segment.upperBound
                else {
                    return [segment]
                }

                var remaining: [ClosedRange<Double>] = []
                if exclusion.lowerBound > segment.lowerBound {
                    remaining.append(segment.lowerBound...exclusion.lowerBound)
                }
                if exclusion.upperBound < segment.upperBound {
                    remaining.append(exclusion.upperBound...segment.upperBound)
                }
                return remaining
            }
        }

        let widest = segments.max { lhs, rhs in
            let lhsWidth = lhs.upperBound - lhs.lowerBound
            let rhsWidth = rhs.upperBound - rhs.lowerBound
            if lhsWidth != rhsWidth {
                return lhsWidth < rhsWidth
            }
            return lhs.lowerBound > rhs.lowerBound
        }
        guard let widest else {
            return options.searchRange.lowerBound
        }
        return widest.lowerBound + ((widest.upperBound - widest.lowerBound) / 2)
    }

    private static func time(at position: Double, duration: Double) -> CMTime {
        CMTime(
            seconds: duration * position,
            preferredTimescale: preferredTimescale
        )
    }
}
