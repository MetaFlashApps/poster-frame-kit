import CoreVideo
import Foundation

struct FrameAnalyzer {
    private var buffer = AnalysisBuffer()

    mutating func analyze(_ pixelBuffer: CVPixelBuffer) throws -> FrameMetrics {
        try buffer.load(from: pixelBuffer)

        let pixelCount = buffer.width * buffer.height
        guard pixelCount > 0 else {
            throw PosterFrameError.invalidPixelBuffer
        }

        let mean = meanLuma(pixelCount: pixelCount)
        let edgeMeasurements = edgeMeasurements()
        return FrameMetrics(
            meanLuma: mean,
            lumaDeviation: lumaDeviation(mean: mean, pixelCount: pixelCount),
            entropy: entropy(pixelCount: pixelCount),
            sharpness: edgeMeasurements.sharpness,
            colorfulness: buffer.colorfulness,
            visualNoise: visualNoise(
                highFrequencyEnergy: edgeMeasurements.highFrequencyEnergy
            )
        )
    }

    private func meanLuma(pixelCount: Int) -> Double {
        let total = buffer.luma.prefix(pixelCount).reduce(0) { sum, value in
            sum + UInt64(value)
        }
        return Double(total) / (Double(pixelCount) * 255)
    }

    private func lumaDeviation(mean: Double, pixelCount: Int) -> Double {
        let squaredDifferences = buffer.luma.prefix(pixelCount).reduce(0.0) { sum, value in
            let normalizedValue = Double(value) / 255
            let difference = normalizedValue - mean
            return sum + difference * difference
        }
        return sqrt(squaredDifferences / Double(pixelCount))
    }

    private func entropy(pixelCount: Int) -> Double {
        var histogram = Array(repeating: 0, count: 256)
        for value in buffer.luma.prefix(pixelCount) {
            histogram[Int(value)] += 1
        }

        let count = Double(pixelCount)
        let bits = histogram.reduce(0.0) { result, frequency in
            guard frequency > 0 else {
                return result
            }
            let probability = Double(frequency) / count
            return result - probability * log2(probability)
        }
        return bits / 8
    }

    private func edgeMeasurements() -> (
        sharpness: Double,
        highFrequencyEnergy: Double
    ) {
        guard buffer.width >= 3, buffer.height >= 3 else {
            return (0, 0)
        }

        var gradientTotal = 0.0
        var highFrequencyTotal = 0.0
        let width = buffer.width

        for y in 1..<(buffer.height - 1) {
            for x in 1..<(width - 1) {
                let center = y * width + x
                let topLeft = Int(buffer.luma[center - width - 1])
                let top = Int(buffer.luma[center - width])
                let topRight = Int(buffer.luma[center - width + 1])
                let left = Int(buffer.luma[center - 1])
                let right = Int(buffer.luma[center + 1])
                let bottomLeft = Int(buffer.luma[center + width - 1])
                let bottom = Int(buffer.luma[center + width])
                let bottomRight = Int(buffer.luma[center + width + 1])

                let gradientX = -topLeft + topRight - 2 * left + 2 * right
                    - bottomLeft + bottomRight
                let gradientY = -topLeft - 2 * top - topRight
                    + bottomLeft + 2 * bottom + bottomRight
                gradientTotal += Double(gradientX * gradientX + gradientY * gradientY)

                let centerLuma = 4 * Int(buffer.luma[center])
                let neighboringLuma = top + left + right + bottom
                highFrequencyTotal += Double(abs(centerLuma - neighboringLuma))
            }
        }

        let interiorPixelCount = Double((buffer.width - 2) * (buffer.height - 2))
        let maximumGradientSquared = 2 * pow(4 * 255.0, 2)
        let normalizedMean = gradientTotal / (interiorPixelCount * maximumGradientSquared)
        let sharpness = min(max(sqrt(normalizedMean), 0), 1)
        let highFrequencyEnergy = highFrequencyTotal / (interiorPixelCount * 4 * 255)
        return (sharpness, min(max(highFrequencyEnergy, 0), 1))
    }

    private func visualNoise(highFrequencyEnergy: Double) -> Double {
        // Ordinary edges remain below the lower bound. Dense, incoherent
        // high-frequency patterns move smoothly toward one rather than
        // introducing a hard rejection boundary.
        let lowerBound = 0.06
        let upperBound = 0.14
        let normalized = min(
            max((highFrequencyEnergy - lowerBound) / (upperBound - lowerBound), 0),
            1
        )
        return normalized * normalized * (3 - 2 * normalized)
    }
}
