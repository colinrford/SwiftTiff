import Testing
import Foundation
@testable import SwiftTiff

@Suite(.serialized)
struct WriteTests {

    // MARK: - Round-trip from existing TIFF

    @Test func writeStrippedChunky() throws {
        let data = try Data(contentsOf: TestFile.stripped.url)
        let image = try TIFFReader.read(from: data)
        var dir = image.fileDirectory
        let rasters = try dir.readRasters()
        let rastersInterleaved = try dir.readInterleavedRasters()

        dir.writeRasters = rasters
        dir.setCompression(.none)
        dir.setPlanarConfiguration(.chunky)
        let rowsPerStrip = rasters.calculateRowsPerStrip(
            planarConfiguration: .chunky
        )
        dir.setRowsPerStrip(rowsPerStrip)

        let outImage = TIFFImage(fileDirectory: dir)
        let tiffBytes = try TIFFWriter.write(image: outImage)

        let readBack = try TIFFReader.read(from: tiffBytes)
        let dir2 = readBack.fileDirectory
        let rasters2 = try dir2.readRasters()
        let rasters2Interleaved = try dir2.readInterleavedRasters()

        compareRastersSampleValues(rasters, rasters2)
        compareRastersInterleaveValues(rastersInterleaved, rasters2Interleaved)
    }

    @Test func writeStrippedPlanar() throws {
        let data = try Data(contentsOf: TestFile.stripped.url)
        let image = try TIFFReader.read(from: data)
        var dir = image.fileDirectory
        let rasters = try dir.readRasters()
        let rastersInterleaved = try dir.readInterleavedRasters()

        dir.writeRasters = rasters
        dir.setCompression(.none)
        dir.setPlanarConfiguration(.planar)
        let rowsPerStrip = rasters.calculateRowsPerStrip(
            planarConfiguration: .planar
        )
        dir.setRowsPerStrip(rowsPerStrip)

        let outImage = TIFFImage(fileDirectory: dir)
        let tiffBytes = try TIFFWriter.write(image: outImage)

        let readBack = try TIFFReader.read(from: tiffBytes)
        let dir2 = readBack.fileDirectory
        let rasters2 = try dir2.readRasters()
        let rasters2Interleaved = try dir2.readInterleavedRasters()

        compareRastersSampleValues(rasters, rasters2)
        compareRastersInterleaveValues(rastersInterleaved, rasters2Interleaved)
    }

    // MARK: - Custom TIFF creation

    @Test func writeCustom() throws {
        let width = 18
        let height = 11
        let bitsPerSample = 16
        let samplesPerPixel = 1

        var rasters = TIFFRasters(
            width: width, height: height,
            samplesPerPixel: samplesPerPixel,
            singleBitsPerSample: bitsPerSample
        )

        var expected = [[Double]](
            repeating: [Double](repeating: 0, count: width),
            count: height
        )
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(Int.random(in: 0..<65536))
                rasters.setFirstPixelSample(x: x, y: y, value: value)
                expected[y][x] = value
            }
        }

        let rowsPerStrip = rasters.calculateRowsPerStrip(
            planarConfiguration: .chunky
        )

        var dir = TIFFFileDirectory()
        dir.setImageWidth(width)
        dir.setImageHeight(height)
        dir.setBitsPerSample([bitsPerSample])
        dir.setSamplesPerPixel(samplesPerPixel)
        dir.setSampleFormat([Int(SampleFormat.unsignedInt.rawValue)])
        dir.setRowsPerStrip(rowsPerStrip)
        dir.setResolutionUnit(.inch)
        dir.setXResolution(254)
        dir.setYResolution(254)
        dir.setPhotometricInterpretation(.blackIsZero)
        dir.setPlanarConfiguration(.chunky)
        dir.setCompression(.none)
        dir.writeRasters = rasters

        let outImage = TIFFImage(fileDirectory: dir)
        let tiffData = try TIFFWriter.write(image: outImage)

        let readImage = try TIFFReader.read(from: tiffData)
        let readDir = readImage.fileDirectory

        #expect(readDir.imageWidth == width)
        #expect(readDir.imageHeight == height)
        #expect(readDir.bitsPerSample == [bitsPerSample])
        #expect(readDir.samplesPerPixel == samplesPerPixel)
        #expect(readDir.sampleFormat == [Int(SampleFormat.unsignedInt.rawValue)])
        #expect(readDir.compression == Compression.none)

        let readRasters = try readDir.readRasters()
        for y in 0..<height {
            for x in 0..<width {
                #expect(
                    readRasters.firstPixelSample(x: x, y: y) == expected[y][x],
                    "Mismatch at (\(x),\(y))"
                )
            }
        }
    }

    // MARK: - API usage example

    @Test func writeAndReadExample() throws {
        let width = 256
        let height = 256
        let samplesPerPixel = 1
        let bitsPerSample = 32

        var rasters = TIFFRasters(
            width: width, height: height,
            samplesPerPixel: samplesPerPixel,
            singleBitsPerSample: bitsPerSample
        )

        for y in 0..<height {
            for x in 0..<width {
                rasters.setFirstPixelSample(x: x, y: y, value: 1.0)
            }
        }

        let rowsPerStrip = rasters.calculateRowsPerStrip(
            planarConfiguration: .chunky
        )

        var dir = TIFFFileDirectory()
        dir.setImageWidth(width)
        dir.setImageHeight(height)
        dir.setBitsPerSample([bitsPerSample])
        dir.setCompression(.none)
        dir.setPhotometricInterpretation(.blackIsZero)
        dir.setSamplesPerPixel(samplesPerPixel)
        dir.setRowsPerStrip(rowsPerStrip)
        dir.setPlanarConfiguration(.chunky)
        dir.setSampleFormat([Int(SampleFormat.float.rawValue)])
        dir.writeRasters = rasters

        let image = TIFFImage(fileDirectory: dir)
        let data = try TIFFWriter.write(image: image)

        let readImage = try TIFFReader.read(from: data)
        let readDir = readImage.fileDirectory
        let readRasters = try readDir.readRasters()

        #expect(readRasters.width == width)
        #expect(readRasters.height == height)
        #expect(readRasters.firstPixelSample(x: 0, y: 0) == 1.0)
        #expect(readRasters.firstPixelSample(x: 127, y: 127) == 1.0)
    }
}
