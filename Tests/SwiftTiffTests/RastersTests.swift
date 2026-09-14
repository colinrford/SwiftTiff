import Testing
@testable import SwiftTiff

struct RastersTests {

    // MARK: - Construction

    @Test func basicConstruction() {
        let rasters = TIFFRasters(width: 256, height: 256, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.width == 256)
        #expect(rasters.height == 256)
        #expect(rasters.samplesPerPixel == 3)
        #expect(rasters.bitsPerSample == [8, 8, 8])
        #expect(rasters.numPixels == 65536)
        #expect(rasters.hasSampleValues == true)
        #expect(rasters.hasInterleaveValues == false)
    }

    @Test func constructionWithExplicitBitsPerSample() {
        let rasters = TIFFRasters(
            width: 10, height: 10, samplesPerPixel: 3,
            bitsPerSample: [8, 16, 32]
        )
        #expect(rasters.bitsPerSample == [8, 16, 32])
    }

    @Test func constructionWithSampleValues() {
        let samples: [[Double]] = [
            [1, 2, 3, 4],
            [5, 6, 7, 8],
            [9, 10, 11, 12]
        ]
        let rasters = TIFFRasters(
            width: 2, height: 2, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8], sampleValues: samples
        )
        #expect(rasters.hasSampleValues == true)
        #expect(rasters.hasInterleaveValues == false)
        #expect(rasters.firstPixelSample(x: 0, y: 0) == 1)
    }

    @Test func constructionWithInterleaveValues() {
        // 2x2 image, 3 samples per pixel = 12 values
        let interleave: [Double] = [
            1, 2, 3,   // pixel (0,0)
            4, 5, 6,   // pixel (1,0)
            7, 8, 9,   // pixel (0,1)
            10, 11, 12  // pixel (1,1)
        ]
        let rasters = TIFFRasters(
            width: 2, height: 2, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8], interleaveValues: interleave
        )
        #expect(rasters.hasSampleValues == false)
        #expect(rasters.hasInterleaveValues == true)
    }

    // MARK: - Pixel access (planar mode)

    @Test func setAndGetPixelPlanar() {
        var rasters = TIFFRasters(width: 4, height: 4, samplesPerPixel: 3, singleBitsPerSample: 8)
        rasters.setPixel(x: 1, y: 2, values: [100, 150, 200])
        let pixel = rasters.pixel(x: 1, y: 2)
        #expect(pixel == [100, 150, 200])
    }

    @Test func setAndGetPixelSamplePlanar() {
        var rasters = TIFFRasters(width: 4, height: 4, samplesPerPixel: 3, singleBitsPerSample: 8)
        rasters.setPixelSample(sample: 0, x: 2, y: 3, value: 42)
        rasters.setPixelSample(sample: 1, x: 2, y: 3, value: 84)
        rasters.setPixelSample(sample: 2, x: 2, y: 3, value: 126)
        #expect(rasters.pixelSample(sample: 0, x: 2, y: 3) == 42)
        #expect(rasters.pixelSample(sample: 1, x: 2, y: 3) == 84)
        #expect(rasters.pixelSample(sample: 2, x: 2, y: 3) == 126)
    }

    @Test func firstPixelSamplePlanar() {
        var rasters = TIFFRasters(width: 4, height: 4, samplesPerPixel: 1, singleBitsPerSample: 8)
        rasters.setFirstPixelSample(x: 0, y: 0, value: 255)
        #expect(rasters.firstPixelSample(x: 0, y: 0) == 255)
    }

    // MARK: - Pixel access (interleaved mode)

    @Test func getPixelInterleaved() {
        let interleave: [Double] = [
            10, 20, 30,  // (0,0)
            40, 50, 60,  // (1,0)
            70, 80, 90,  // (0,1)
            100, 110, 120 // (1,1)
        ]
        let rasters = TIFFRasters(
            width: 2, height: 2, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8], interleaveValues: interleave
        )
        #expect(rasters.pixel(x: 0, y: 0) == [10, 20, 30])
        #expect(rasters.pixel(x: 1, y: 0) == [40, 50, 60])
        #expect(rasters.pixel(x: 0, y: 1) == [70, 80, 90])
        #expect(rasters.pixel(x: 1, y: 1) == [100, 110, 120])
    }

    @Test func setPixelInterleaved() {
        var rasters = TIFFRasters(
            width: 2, height: 2, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8],
            interleaveValues: [Double](repeating: 0, count: 12)
        )
        rasters.setPixel(x: 1, y: 1, values: [255, 128, 64])
        #expect(rasters.pixel(x: 1, y: 1) == [255, 128, 64])
        // Other pixels unchanged
        #expect(rasters.pixel(x: 0, y: 0) == [0, 0, 0])
    }

    @Test func pixelSampleInterleaved() {
        let interleave: [Double] = [10, 20, 30, 40, 50, 60]
        let rasters = TIFFRasters(
            width: 2, height: 1, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8], interleaveValues: interleave
        )
        #expect(rasters.pixelSample(sample: 0, x: 1, y: 0) == 40)
        #expect(rasters.pixelSample(sample: 1, x: 1, y: 0) == 50)
        #expect(rasters.pixelSample(sample: 2, x: 1, y: 0) == 60)
    }

    // MARK: - Builder methods

    @Test func setSampleValue() {
        var rasters = TIFFRasters(width: 3, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        // Set pixel at (2, 1) which is index 5 (y * width + x = 1 * 3 + 2)
        rasters.setSampleValue(42, sampleIndex: 0, coordinateIndex: 5)
        #expect(rasters.firstPixelSample(x: 2, y: 1) == 42)
    }

    @Test func setInterleaveValue() {
        var rasters = TIFFRasters(
            width: 2, height: 1, samplesPerPixel: 3,
            bitsPerSample: [8, 8, 8],
            interleaveValues: [Double](repeating: 0, count: 6)
        )
        // Pixel (1,0) starts at interleave index 3
        rasters.setInterleaveValue(100, at: 3)
        rasters.setInterleaveValue(200, at: 4)
        rasters.setInterleaveValue(255, at: 5)
        #expect(rasters.pixel(x: 1, y: 0) == [100, 200, 255])
    }

    // MARK: - Index calculations

    @Test func sampleIndex() {
        let rasters = TIFFRasters(width: 10, height: 5, samplesPerPixel: 1, singleBitsPerSample: 8)
        #expect(rasters.sampleIndex(x: 0, y: 0) == 0)
        #expect(rasters.sampleIndex(x: 9, y: 0) == 9)
        #expect(rasters.sampleIndex(x: 0, y: 1) == 10)
        #expect(rasters.sampleIndex(x: 3, y: 2) == 23)
    }

    @Test func interleaveIndex() {
        let rasters = TIFFRasters(width: 10, height: 5, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.interleaveIndex(x: 0, y: 0) == 0)
        #expect(rasters.interleaveIndex(x: 1, y: 0) == 3)
        #expect(rasters.interleaveIndex(x: 0, y: 1) == 30)
    }

    // MARK: - Size calculations

    @Test func sizeCalculations() {
        let rasters = TIFFRasters(width: 100, height: 200, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.sizeSample(0) == 1)
        #expect(rasters.sizePixel == 3)
        #expect(rasters.size == 60_000) // 100 * 200 * 3
    }

    @Test func sizeWithMixedBitsPerSample() {
        let rasters = TIFFRasters(
            width: 10, height: 10, samplesPerPixel: 3,
            bitsPerSample: [8, 16, 32]
        )
        #expect(rasters.sizeSample(0) == 1)
        #expect(rasters.sizeSample(1) == 2)
        #expect(rasters.sizeSample(2) == 4)
        #expect(rasters.sizePixel == 7) // 1 + 2 + 4
        #expect(rasters.size == 700) // 100 * 7
    }

    // MARK: - Rows per strip

    @Test func rowsPerStripChunky() {
        // 100px wide, 3 samples * 8 bits = 3 bytes/pixel, 300 bytes/row
        // Default max 8000 bytes -> 8000 / 300 = 26 rows
        let rasters = TIFFRasters(width: 100, height: 100, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.calculateRowsPerStrip(planarConfiguration: .chunky) == 26)
    }

    @Test func rowsPerStripPlanar() {
        // 100px wide, each sample is 8 bits = 1 byte/pixel, 100 bytes/row
        // Default max 8000 bytes -> 8000 / 100 = 80 rows
        let rasters = TIFFRasters(width: 100, height: 100, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.calculateRowsPerStrip(planarConfiguration: .planar) == 80)
    }

    @Test func rowsPerStripCustomMax() {
        let rasters = TIFFRasters(width: 100, height: 100, samplesPerPixel: 3, singleBitsPerSample: 8)
        // 500 bytes max, 300 bytes/row -> 1 row
        #expect(rasters.calculateRowsPerStrip(planarConfiguration: .chunky, maxBytesPerStrip: 500) == 1)
    }

    @Test func rowsPerStripMinimumOne() {
        // Very narrow max that's less than one row
        let rasters = TIFFRasters(width: 1000, height: 10, samplesPerPixel: 3, singleBitsPerSample: 8)
        #expect(rasters.calculateRowsPerStrip(planarConfiguration: .chunky, maxBytesPerStrip: 1) == 1)
    }

    // MARK: - Full image round-trip

    @Test func grayscaleRoundTrip() {
        var rasters = TIFFRasters(width: 4, height: 4, samplesPerPixel: 1, singleBitsPerSample: 8)
        // Fill with sequential values
        for y in 0..<4 {
            for x in 0..<4 {
                rasters.setFirstPixelSample(x: x, y: y, value: Double(y * 4 + x))
            }
        }
        // Read back
        for y in 0..<4 {
            for x in 0..<4 {
                #expect(rasters.firstPixelSample(x: x, y: y) == Double(y * 4 + x))
            }
        }
    }

    @Test func rgbRoundTrip() {
        var rasters = TIFFRasters(width: 2, height: 2, samplesPerPixel: 3, singleBitsPerSample: 8)
        rasters.setPixel(x: 0, y: 0, values: [255, 0, 0])   // red
        rasters.setPixel(x: 1, y: 0, values: [0, 255, 0])   // green
        rasters.setPixel(x: 0, y: 1, values: [0, 0, 255])   // blue
        rasters.setPixel(x: 1, y: 1, values: [255, 255, 255]) // white

        #expect(rasters.pixel(x: 0, y: 0) == [255, 0, 0])
        #expect(rasters.pixel(x: 1, y: 0) == [0, 255, 0])
        #expect(rasters.pixel(x: 0, y: 1) == [0, 0, 255])
        #expect(rasters.pixel(x: 1, y: 1) == [255, 255, 255])
    }

    // MARK: - Equatable

    @Test func equality() {
        let a = TIFFRasters(width: 2, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        let b = TIFFRasters(width: 2, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        #expect(a == b)
    }

    @Test func inequalityAfterMutation() {
        var a = TIFFRasters(width: 2, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        let b = TIFFRasters(width: 2, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        a.setFirstPixelSample(x: 0, y: 0, value: 42)
        #expect(a != b)
    }

    // MARK: - Default zero-initialization

    @Test func newRastersAreZeroFilled() {
        let rasters = TIFFRasters(width: 4, height: 4, samplesPerPixel: 3, singleBitsPerSample: 8)
        for y in 0..<4 {
            for x in 0..<4 {
                #expect(rasters.pixel(x: x, y: y) == [0, 0, 0])
            }
        }
    }
}
