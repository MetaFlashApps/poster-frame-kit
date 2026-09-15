import CoreVideo
import Foundation

package struct SubtitleBandHeuristic {
    private var buffer = AnalysisBuffer(maximumDimension: 320)

    package init() {}

    package mutating func isSuspicious(_ pixelBuffer: CVPixelBuffer) throws -> Bool {
        try diagnostics(pixelBuffer).isSuspicious
    }

    package mutating func diagnostics(
        _ pixelBuffer: CVPixelBuffer
    ) throws -> SubtitleBandDiagnostics {
        try buffer.load(from: pixelBuffer)
        guard buffer.width >= 8, buffer.height >= 12 else {
            return .none
        }

        let firstRow = max(1, buffer.height * 2 / 3)
        let lastRow = buffer.height - 1
        let firstColumn = max(1, buffer.width / 20)
        let lastColumn = min(buffer.width - 1, buffer.width * 19 / 20)
        guard firstRow < lastRow, firstColumn < lastColumn else {
            return .none
        }

        var rowEdges = Array(repeating: 0, count: lastRow - firstRow)
        var rowBrightStrokes = Array(repeating: 0, count: lastRow - firstRow)
        for y in firstRow..<lastRow {
            var count = 0
            var brightStrokeCount = 0
            for x in firstColumn..<lastColumn {
                let index = y * buffer.width + x
                let center = Int(buffer.luma[index])
                let left = Int(buffer.luma[index - 1])
                let right = Int(buffer.luma[index + 1])
                let above = Int(buffer.luma[index - buffer.width])
                let below = Int(buffer.luma[index + buffer.width])
                let horizontal = abs(
                    right - left
                )
                let vertical = abs(
                    below - above
                )
                if max(horizontal, vertical) >= 64 {
                    count += 1
                }
                let darkestNeighbor = min(left, right, above, below)
                if center >= 180, center - darkestNeighbor >= 96 {
                    brightStrokeCount += 1
                }
            }
            rowEdges[y - firstRow] = count
            rowBrightStrokes[y - firstRow] = brightStrokeCount
        }

        let totalEdges = rowEdges.reduce(0, +)
        let inspectedWidth = lastColumn - firstColumn
        let inspectedPixels = inspectedWidth * rowEdges.count
        let windowHeight = min(max(rowEdges.count / 5, 3), rowEdges.count)
        let edgeMetrics = windowMetrics(
            rows: rowEdges,
            windowHeight: windowHeight,
            inspectedWidth: inspectedWidth
        )
        let brightStrokeMetrics = windowMetrics(
            rows: rowBrightStrokes,
            windowHeight: windowHeight,
            inspectedWidth: inspectedWidth
        )
        let brightStrokeCount = rowBrightStrokes.reduce(0, +)
        let hasEnoughEdges = totalEdges >= max(inspectedPixels / 100, 4)
        // Small outlined subtitles can disappear from Vision's fast pass on
        // busy footage. Restrict this retry signal to bright, high-contrast
        // strokes that are concentrated in a narrow part of the lower band.
        let hasConcentratedBrightStrokes = brightStrokeCount >= 80
            && brightStrokeMetrics.concentration >= 0.33
            && (
                brightStrokeMetrics.density >= 0.045
                    || totalEdges < 1_500
                    || brightStrokeMetrics.concentration >= 0.75
            )
        return SubtitleBandDiagnostics(
            totalEdgeCount: totalEdges,
            concentration: edgeMetrics.concentration,
            windowDensity: edgeMetrics.density,
            brightStrokeCount: brightStrokeCount,
            brightStrokeConcentration: brightStrokeMetrics.concentration,
            brightStrokeWindowDensity: brightStrokeMetrics.density,
            isSuspicious: hasEnoughEdges
                && (
                    edgeMetrics.concentration >= 0.32
                        && edgeMetrics.density >= 0.035
                        || hasConcentratedBrightStrokes
                )
        )
    }

    private func windowMetrics(
        rows: [Int],
        windowHeight: Int,
        inspectedWidth: Int
    ) -> (concentration: Double, density: Double) {
        let total = rows.reduce(0, +)
        guard total > 0 else {
            return (0, 0)
        }
        var windowTotal = rows.prefix(windowHeight).reduce(0, +)
        var maximumWindowTotal = windowTotal
        if rows.count > windowHeight {
            for index in windowHeight..<rows.count {
                windowTotal += rows[index]
                windowTotal -= rows[index - windowHeight]
                maximumWindowTotal = max(maximumWindowTotal, windowTotal)
            }
        }
        return (
            Double(maximumWindowTotal) / Double(total),
            Double(maximumWindowTotal) / Double(inspectedWidth * windowHeight)
        )
    }
}

package struct SubtitleBandDiagnostics: Equatable, Sendable {
    package let totalEdgeCount: Int
    package let concentration: Double
    package let windowDensity: Double
    package let brightStrokeCount: Int
    package let brightStrokeConcentration: Double
    package let brightStrokeWindowDensity: Double
    package let isSuspicious: Bool

    package static let none = SubtitleBandDiagnostics(
        totalEdgeCount: 0,
        concentration: 0,
        windowDensity: 0,
        brightStrokeCount: 0,
        brightStrokeConcentration: 0,
        brightStrokeWindowDensity: 0,
        isSuspicious: false
    )
}
