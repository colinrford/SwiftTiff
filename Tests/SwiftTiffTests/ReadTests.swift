import Testing
import Foundation
@testable import SwiftTiff

@Suite(.serialized)
struct ReadTests {

    // MARK: - Header parsing

    @Test func readStrippedTiff() throws {
        let data = try Data(contentsOf: TestFile.stripped.url)
        let image = try TIFFReader.read(from: data)
        #expect(image.fileDirectories.count >= 1)

        let dir = image.fileDirectory
        #expect(dir.imageWidth == 539)
        #expect(dir.imageHeight == 448)
        #expect(dir.samplesPerPixel == 15)
        #expect(dir.bitsPerSample?.first == 16)
        #expect(dir.compression == Compression.none)
        #expect(dir.isTiled == false)
    }

    @Test func readTiledTiff() throws {
        let data = try Data(contentsOf: TestFile.tiled.url)
        let image = try TIFFReader.read(from: data)
        let dir = image.fileDirectory
        #expect(dir.isTiled == true)
        #expect(dir.tileWidth != nil)
        #expect(dir.tileHeight != nil)
    }

    @Test func readLzwTiff() throws {
        let data = try Data(contentsOf: TestFile.lzw.url)
        let image = try TIFFReader.read(from: data)
        let dir = image.fileDirectory
        #expect(dir.compression == .lzw)
    }

    @Test func readPackbitsTiff() throws {
        let data = try Data(contentsOf: TestFile.packbits.url)
        let image = try TIFFReader.read(from: data)
        let dir = image.fileDirectory
        #expect(dir.compression == .packbits)
    }

    // MARK: - Raster comparisons

    @Test func strippedVsTiled() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let tiled = try TIFFReader.read(from: Data(contentsOf: TestFile.tiled.url))
        try compareTIFFImages(stripped, tiled)
    }

    @Test func strippedVsInt32() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let int32 = try TIFFReader.read(from: Data(contentsOf: TestFile.int32.url))
        try compareTIFFImages(stripped, int32, exactType: true, sameBitsPerSample: false)
    }

    @Test func strippedVsUInt32() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let uint32 = try TIFFReader.read(from: Data(contentsOf: TestFile.uint32.url))
        try compareTIFFImages(stripped, uint32, exactType: false, sameBitsPerSample: false)
    }

    @Test func strippedVsFloat32() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let float32 = try TIFFReader.read(from: Data(contentsOf: TestFile.float32.url))
        try compareTIFFImages(stripped, float32, exactType: false, sameBitsPerSample: false)
    }

    @Test func strippedVsFloat64() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let float64 = try TIFFReader.read(from: Data(contentsOf: TestFile.float64.url))
        try compareTIFFImages(stripped, float64, exactType: false, sameBitsPerSample: false)
    }

    @Test func strippedVsLzw() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let lzw = try TIFFReader.read(from: Data(contentsOf: TestFile.lzw.url))
        try compareTIFFImages(stripped, lzw)
    }

    @Test func strippedVsPackbits() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let packbits = try TIFFReader.read(from: Data(contentsOf: TestFile.packbits.url))
        try compareTIFFImages(stripped, packbits)
    }

    @Test func strippedVsInterleave() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let interleave = try TIFFReader.read(from: Data(contentsOf: TestFile.interleave.url))
        try compareTIFFImages(stripped, interleave)
    }

    @Test func strippedVsTiledPlanar() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let tiledPlanar = try TIFFReader.read(from: Data(contentsOf: TestFile.tiledPlanar.url))
        try compareTIFFImages(stripped, tiledPlanar)
    }

    @Test func strippedVsLzwPredictor() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let lzwPred = try TIFFReader.read(from: Data(contentsOf: TestFile.lzwPredictor.url))
        try compareTIFFImages(stripped, lzwPred)
    }

    @Test func strippedVsTiledPlanarLzw() throws {
        let stripped = try TIFFReader.read(from: Data(contentsOf: TestFile.stripped.url))
        let tiledPlanarLzw = try TIFFReader.read(from: Data(contentsOf: TestFile.tiledPlanarLzw.url))
        try compareTIFFImages(stripped, tiledPlanarLzw)
    }

    @Test func float32VsLzwPredictorFloating() throws {
        let float32 = try TIFFReader.read(from: Data(contentsOf: TestFile.float32.url))
        let lzwPredFloat = try TIFFReader.read(from: Data(contentsOf: TestFile.lzwPredictorFloating.url))
        try compareTIFFImages(float32, lzwPredFloat)
    }

    @Test func jpegHeaderOnly() throws {
        let data = try Data(contentsOf: TestFile.jpeg.url)
        let image = try TIFFReader.read(from: data)
        #expect(image.fileDirectories.count > 0)

        for dir in image.fileDirectories {
            #expect(throws: TIFFError.self) {
                try dir.readRasters()
            }
        }
    }

    // MARK: - Interleaved raster reading

    @Test func readInterleavedRasters() throws {
        let data = try Data(contentsOf: TestFile.stripped.url)
        let image = try TIFFReader.read(from: data)
        let dir = image.fileDirectory
        let rasters = try dir.readInterleavedRasters()
        #expect(rasters.hasInterleaveValues == true)
        #expect(rasters.hasSampleValues == false)
        #expect(rasters.width == dir.imageWidth!)
        #expect(rasters.height == dir.imageHeight!)
    }

    // MARK: - TIFFImage

    @Test func tiffImageSizeCalculations() throws {
        let data = try Data(contentsOf: TestFile.stripped.url)
        let image = try TIFFReader.read(from: data)
        #expect(image.sizeHeaderAndDirectories > TIFF.headerBytes)
        #expect(image.sizeHeaderAndDirectoriesWithValues >= image.sizeHeaderAndDirectories)
    }

    // MARK: - Invalid data

    @Test func invalidByteOrderThrows() {
        let data = Data([0x00, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08])
        #expect(throws: TIFFError.self) {
            try TIFFReader.read(from: data)
        }
    }

    @Test func invalidIdentifierThrows() {
        let data = Data([0x4D, 0x4D, 0x00, 0x43, 0x00, 0x00, 0x00, 0x08])
        #expect(throws: TIFFError.self) {
            try TIFFReader.read(from: data)
        }
    }
}
