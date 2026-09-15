/// Normalized measurements used to explain and rank a frame.
public struct FrameMetrics: Equatable, Sendable {
    /// Average luma in the range `0...1`.
    public let meanLuma: Double

    /// Population standard deviation of normalized luma in the range
    /// `0...0.5`.
    public let lumaDeviation: Double

    /// Normalized Shannon entropy of the luma histogram in the range `0...1`.
    public let entropy: Double

    /// Normalized Tenengrad edge strength in the range `0...1`.
    public let sharpness: Double

    /// Average chroma magnitude in the range `0...1`.
    public let colorfulness: Double

    /// Normalized estimate of incoherent high-frequency visual noise in the
    /// range `0...1`.
    public let visualNoise: Double

    /// Creates an immutable set of normalized frame metrics.
    ///
    /// - Parameters:
    ///   - meanLuma: Average normalized brightness.
    ///   - lumaDeviation: Population standard deviation of normalized luma.
    ///   - entropy: Normalized Shannon entropy of the luma histogram.
    ///   - sharpness: Normalized edge strength.
    ///   - colorfulness: Normalized chroma magnitude.
    ///   - visualNoise: Normalized incoherent high-frequency noise estimate.
    public init(
        meanLuma: Double,
        lumaDeviation: Double,
        entropy: Double,
        sharpness: Double,
        colorfulness: Double,
        visualNoise: Double
    ) {
        self.meanLuma = meanLuma
        self.lumaDeviation = lumaDeviation
        self.entropy = entropy
        self.sharpness = sharpness
        self.colorfulness = colorfulness
        self.visualNoise = visualNoise
    }
}
