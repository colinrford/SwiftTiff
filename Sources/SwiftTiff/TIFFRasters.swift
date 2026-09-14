import Foundation

/// Pixel raster data for a TIFF image.
///
/// Stores pixel sample values in one of two modes:
/// - **Sample (planar)**: Separate array per sample channel.
/// - **Interleave**: Single flat array with samples interleaved per pixel.
///
/// These modes are mutually exclusive.
/// The mode is set at initialization.
public struct TIFFRasters: Sendable, Equatable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// Number of samples per pixel (e.g., 3 for RGB, 4 for RGBA).
    public let samplesPerPixel: Int
    /// Bits per sample for each sample channel.
    public let bitsPerSample: [Int]

    /// Planar storage: `samples[sampleIndex][pixelIndex]`.
    /// Nil when using interleaved mode.
    private var sampleArrays: [[Double]]?

    /// Interleaved storage: flat array of `width * height * samplesPerPixel`.
    /// Nil when using planar mode.
    private var interleaveArray: [Double]?

    // MARK: - Initializers

    /// Creates rasters with empty planar storage (all values zero).
    /// ObjC: `initWithWidth:andHeight:andSamplesPerPixel:andBitsPerSample:`
    public init(
        width: Int,
        height: Int,
        samplesPerPixel: Int,
        bitsPerSample: [Int]
    ) {
        precondition(width > 0 && height > 0, "Dimensions must be positive")
        precondition(samplesPerPixel > 0, "Must have at least one sample")
        precondition(bitsPerSample.count == samplesPerPixel,
                     "bitsPerSample count must match samplesPerPixel")
        precondition(bitsPerSample.allSatisfy { $0 > 0 && $0 % 8 == 0 },
                     "All bitsPerSample must be positive multiples of 8")
        self.width = width
        self.height = height
        self.samplesPerPixel = samplesPerPixel
        self.bitsPerSample = bitsPerSample
        let pixelCount = width * height
        self.sampleArrays = (0..<samplesPerPixel).map { _ in
            [Double](repeating: 0, count: pixelCount)
        }
        self.interleaveArray = nil
    }

    /// Creates rasters with uniform bits per sample for all channels.
    /// ObjC: `initWithWidth:andHeight:andSamplesPerPixel:andSingleBitsPerSample:`
    public init(
        width: Int,
        height: Int,
        samplesPerPixel: Int,
        singleBitsPerSample: Int
    ) {
        self.init(
            width: width,
            height: height,
            samplesPerPixel: samplesPerPixel,
            bitsPerSample: [Int](repeating: singleBitsPerSample, count: samplesPerPixel)
        )
    }

    /// Creates rasters with pre-filled planar sample values.
    /// ObjC: `initWithWidth:andHeight:andSamplesPerPixel:andBitsPerSample:andSampleValues:`
    public init(
        width: Int,
        height: Int,
        samplesPerPixel: Int,
        bitsPerSample: [Int],
        sampleValues: [[Double]]
    ) {
        precondition(width > 0 && height > 0, "Dimensions must be positive")
        precondition(samplesPerPixel > 0, "Must have at least one sample")
        precondition(bitsPerSample.count == samplesPerPixel,
                     "bitsPerSample count must match samplesPerPixel")
        precondition(bitsPerSample.allSatisfy { $0 > 0 && $0 % 8 == 0 },
                     "All bitsPerSample must be positive multiples of 8")
        precondition(sampleValues.count == samplesPerPixel,
                     "sampleValues count must match samplesPerPixel")
        let pixelCount = width * height
        precondition(sampleValues.allSatisfy { $0.count == pixelCount },
                     "Each sample array must have width * height entries")
        self.width = width
        self.height = height
        self.samplesPerPixel = samplesPerPixel
        self.bitsPerSample = bitsPerSample
        self.sampleArrays = sampleValues
        self.interleaveArray = nil
    }

    /// Creates rasters with pre-filled interleaved values.
    /// ObjC: `initWithWidth:andHeight:andSamplesPerPixel:andBitsPerSample:andInterleaveValues:`
    public init(
        width: Int,
        height: Int,
        samplesPerPixel: Int,
        bitsPerSample: [Int],
        interleaveValues: [Double]
    ) {
        precondition(width > 0 && height > 0, "Dimensions must be positive")
        precondition(samplesPerPixel > 0, "Must have at least one sample")
        precondition(bitsPerSample.count == samplesPerPixel,
                     "bitsPerSample count must match samplesPerPixel")
        precondition(bitsPerSample.allSatisfy { $0 > 0 && $0 % 8 == 0 },
                     "All bitsPerSample must be positive multiples of 8")
        precondition(interleaveValues.count == width * height * samplesPerPixel,
                     "interleaveValues count must be width * height * samplesPerPixel")
        self.width = width
        self.height = height
        self.samplesPerPixel = samplesPerPixel
        self.bitsPerSample = bitsPerSample
        self.sampleArrays = nil
        self.interleaveArray = interleaveValues
    }

    // MARK: - Storage mode queries

    /// True if values are stored in planar (per-sample) mode.
    public var hasSampleValues: Bool { sampleArrays != nil }

    /// True if values are stored in interleaved mode.
    public var hasInterleaveValues: Bool { interleaveArray != nil }

    // MARK: - Dimensions

    /// Total number of pixels.
    public var numPixels: Int { width * height }

    // MARK: - Index calculations

    /// Linear pixel index for planar storage.
    /// ObjC: `sampleIndexAtX:andY:` → `y * width + x`
    public func sampleIndex(x: Int, y: Int) -> Int {
        y * width + x
    }

    /// Base index for interleaved storage.
    /// ObjC: `interleaveIndexAtX:andY:` → `(y * width * samplesPerPixel) + (x * samplesPerPixel)`
    public func interleaveIndex(x: Int, y: Int) -> Int {
        (y * width + x) * samplesPerPixel
    }

    // MARK: - Pixel access

    /// Get all sample values at a pixel coordinate.
    /// ObjC: `pixelAtX:andY:`
    public func pixel(x: Int, y: Int) -> [Double] {
        validateCoordinates(x: x, y: y)
        var values = [Double]()
        values.reserveCapacity(samplesPerPixel)

        if let samples = sampleArrays {
            let idx = sampleIndex(x: x, y: y)
            for s in 0..<samplesPerPixel {
                values.append(samples[s][idx])
            }
        } else if let interleave = interleaveArray {
            let idx = interleaveIndex(x: x, y: y)
            for s in 0..<samplesPerPixel {
                values.append(interleave[idx + s])
            }
        }
        return values
    }

    /// Set all sample values at a pixel coordinate.
    /// ObjC: `setPixelAtX:andY:withValues:`
    public mutating func setPixel(x: Int, y: Int, values: [Double]) {
        validateCoordinates(x: x, y: y)
        precondition(values.count == samplesPerPixel,
                     "values count (\(values.count)) must equal samplesPerPixel (\(samplesPerPixel))")

        if sampleArrays != nil {
            let idx = sampleIndex(x: x, y: y)
            for s in 0..<samplesPerPixel {
                sampleArrays![s][idx] = values[s]
            }
        } else if interleaveArray != nil {
            let idx = interleaveIndex(x: x, y: y)
            for s in 0..<samplesPerPixel {
                interleaveArray![idx + s] = values[s]
            }
        }
    }

    /// Get a single sample value at a pixel coordinate.
    /// ObjC: `pixelSampleAtSample:andX:andY:`
    public func pixelSample(sample: Int, x: Int, y: Int) -> Double {
        validateCoordinates(x: x, y: y)
        validateSample(sample)

        if let samples = sampleArrays {
            return samples[sample][sampleIndex(x: x, y: y)]
        } else if let interleave = interleaveArray {
            return interleave[interleaveIndex(x: x, y: y) + sample]
        }
        preconditionFailure("No storage")
    }

    /// Set a single sample value at a pixel coordinate.
    /// ObjC: `setPixelSampleAtSample:andX:andY:withValue:`
    public mutating func setPixelSample(sample: Int, x: Int, y: Int, value: Double) {
        validateCoordinates(x: x, y: y)
        validateSample(sample)

        if sampleArrays != nil {
            sampleArrays![sample][sampleIndex(x: x, y: y)] = value
        } else if interleaveArray != nil {
            interleaveArray![interleaveIndex(x: x, y: y) + sample] = value
        }
    }

    /// Get the first sample value (convenience for grayscale).
    /// ObjC: `firstPixelSampleAtX:andY:`
    public func firstPixelSample(x: Int, y: Int) -> Double {
        pixelSample(sample: 0, x: x, y: y)
    }

    /// Set the first sample value (convenience for grayscale).
    /// ObjC: `setFirstPixelSampleAtX:andY:withValue:`
    public mutating func setFirstPixelSample(x: Int, y: Int, value: Double) {
        setPixelSample(sample: 0, x: x, y: y, value: value)
    }

    // MARK: - Builder methods (used by reader during decode)

    /// Set a value in planar storage at a specific sample and coordinate index.
    /// ObjC: `addSampleValue:toIndex:andCoordinate:`
    ///
    /// - Precondition: Storage must be planar.
    public mutating func setSampleValue(
        _ value: Double,
        sampleIndex: Int,
        coordinateIndex: Int
    ) {
        sampleArrays![sampleIndex][coordinateIndex] = value
    }

    /// Set a value in interleaved storage at a specific coordinate index.
    /// ObjC: `addInterleaveValue:toCoordinate:`
    ///
    /// - Precondition: Storage must be interleaved.
    public mutating func setInterleaveValue(_ value: Double, at coordinateIndex: Int) {
        interleaveArray![coordinateIndex] = value
    }

    // MARK: - Size calculations

    /// Total size in bytes of the image data.
    /// ObjC: `size` → `numPixels * sizePixel`
    public var size: Int {
        numPixels * sizePixel
    }

    /// Size in bytes of a single pixel (sum of all sample sizes).
    /// ObjC: `sizePixel`
    public var sizePixel: Int {
        bitsPerSample.reduce(0) { $0 + $1 / 8 }
    }

    /// Size in bytes of a single sample.
    /// ObjC: `sizeSample:`
    public func sizeSample(_ sample: Int) -> Int {
        bitsPerSample[sample] / 8
    }

    /// Calculate optimal rows per strip for writing.
    /// ObjC: `calculateRowsPerStripWithPlanarConfiguration:`
    public func calculateRowsPerStrip(
        planarConfiguration: PlanarConfiguration
    ) -> Int {
        calculateRowsPerStrip(
            planarConfiguration: planarConfiguration,
            maxBytesPerStrip: TIFF.defaultMaxBytesPerStrip
        )
    }

    /// Calculate optimal rows per strip for writing with custom max bytes.
    /// ObjC: `calculateRowsPerStripWithPlanarConfiguration:andMaxBytesPerStrip:`
    public func calculateRowsPerStrip(
        planarConfiguration: PlanarConfiguration,
        maxBytesPerStrip: Int
    ) -> Int {
        switch planarConfiguration {
        case .chunky:
            let bitsPerPixel = bitsPerSample.reduce(0, +)
            return rowsPerStrip(bitsPerPixel: bitsPerPixel, maxBytesPerStrip: maxBytesPerStrip)
        case .planar:
            var result = Int.max
            for sampleBits in bitsPerSample {
                let rows = rowsPerStrip(bitsPerPixel: sampleBits, maxBytesPerStrip: maxBytesPerStrip)
                result = min(result, rows)
            }
            return result
        }
    }

    // MARK: - Private helpers

    private func rowsPerStrip(bitsPerPixel: Int, maxBytesPerStrip: Int) -> Int {
        let bytesPerPixel = (bitsPerPixel + 7) / 8  // ceil division
        let bytesPerRow = bytesPerPixel * width
        guard bytesPerRow > 0 else { return 1 }
        return max(1, maxBytesPerStrip / bytesPerRow)
    }

    /// Bug fix: ObjC used `y > self.height` instead of `y >= self.height`.
    private func validateCoordinates(x: Int, y: Int) {
        precondition(
            x >= 0 && x < width && y >= 0 && y < height,
            "Pixel out of bounds. Width: \(width), Height: \(height), x: \(x), y: \(y)"
        )
    }

    private func validateSample(_ sample: Int) {
        precondition(
            sample >= 0 && sample < samplesPerPixel,
            "Sample out of bounds. sample: \(sample), samplesPerPixel: \(samplesPerPixel)"
        )
    }
}
