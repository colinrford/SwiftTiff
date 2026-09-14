import Testing
import Foundation
@testable import SwiftTiff

/// Inputs that previously trapped (crashed) and must now throw or succeed.
struct MalformedInputTests {

    // MARK: - Reader structure

    @Test func ifdLoopThrows() {
        // Header → IFD at 8 with 0 entries whose next-IFD offset points back to 8
        var w = ByteWriter(byteOrder: .littleEndian)
        w.writeString("II")
        w.writeUInt16(42)
        w.writeUInt32(8)
        w.writeUInt16(0)
        w.writeUInt32(8)
        expectTIFFError(\.isInvalidData) { _ = try TIFFReader.read(from: w.data) }
    }

    @Test func oversizedValueCountThrows() {
        // One LONG entry claiming 0x7FFFFFFF values at offset 0
        var w = ByteWriter(byteOrder: .littleEndian)
        w.writeString("II")
        w.writeUInt16(42)
        w.writeUInt32(8)
        w.writeUInt16(1)
        w.writeUInt16(FieldTagType.stripOffsets.rawValue)
        w.writeUInt16(FieldType.long.rawValue)
        w.writeUInt32(0x7FFF_FFFF)
        w.writeUInt32(0)
        w.writeUInt32(0)
        expectTIFFError(\.isUnexpectedEndOfData) { _ = try TIFFReader.read(from: w.data) }
    }

    // MARK: - Raster reading

    @Test func shortDecodedStripThrows() {
        // 4 pixels need 4 bytes, but the strip holds 2
        let dir = directory(
            width: 4, height: 1, bitsPerSample: [8],
            pixelData: [1, 2], stripOffsets: [0], stripByteCounts: [2]
        )
        expectTIFFError(\.isInvalidData) { _ = try dir.readRasters() }
    }

    @Test func missingStripThrows() {
        // Two rows at one row per strip, but only one strip listed
        let dir = directory(
            width: 1, height: 2, bitsPerSample: [8],
            pixelData: [1, 2], stripOffsets: [0], stripByteCounts: [1], rowsPerStrip: 1
        )
        expectTIFFError(\.isInvalidData) { _ = try dir.readRasters() }
    }

    @Test func zeroTileWidthThrows() {
        var entries = baseEntries(width: 1, height: 1, bitsPerSample: [8])
        entries[.tileWidth] = entry(.tileWidth, .short, [.short(0)])
        entries[.tileLength] = entry(.tileLength, .short, [.short(1)])
        entries[.tileOffsets] = entry(.tileOffsets, .long, [.long(0)])
        entries[.tileByteCounts] = entry(.tileByteCounts, .long, [.long(1)])
        let dir = TIFFFileDirectory(entries: entries, fileData: Data([7]), fileByteOrder: .littleEndian)
        expectTIFFError(\.isInvalidData) { _ = try dir.readRasters() }
    }

    @Test func nonByteAlignedBitsPerSampleThrows() {
        let dir = directory(
            width: 8, height: 1, bitsPerSample: [1],
            pixelData: [0xFF], stripOffsets: [0], stripByteCounts: [1]
        )
        expectTIFFError(\.isUnsupported) { _ = try dir.readRasters() }
    }

    @Test func nonFiniteDimensionIsMissing() {
        var entries = baseEntries(width: 1, height: 1, bitsPerSample: [8])
        entries[.imageWidth] = entry(.imageWidth, .float, [.float(.nan)])
        let dir = TIFFFileDirectory(entries: entries, fileData: Data([0]), fileByteOrder: .littleEndian)
        #expect(dir.imageWidth == nil)
        expectTIFFError(\.isInvalidData) { _ = try dir.readRasters() }
    }

    @Test func emptyBitsPerSampleInPredictorThrows() {
        expectTIFFError(\.isUnsupportedPredictor) {
            _ = try Predictor.decode(
                data: Data([1]), predictor: .horizontal, width: 1, height: 1,
                bitsPerSample: [], planarConfiguration: .chunky
            )
        }
    }

    // MARK: - Raster reading arguments

    @Test func readSampleSubset() throws {
        // 2x1 RGB: (10, 20, 30), (40, 50, 60)
        let dir = directory(
            width: 2, height: 1, bitsPerSample: [8, 8, 8],
            pixelData: [10, 20, 30, 40, 50, 60], stripOffsets: [0], stripByteCounts: [6]
        )
        let window = ImageWindow(minX: 0, minY: 0, maxX: 2, maxY: 1)

        let blue = try dir.readRasters(window: window, samples: [2], sampleValues: true, interleaveValues: false)
        #expect(blue.samplesPerPixel == 1)
        #expect(blue.pixel(x: 0, y: 0) == [30])
        #expect(blue.pixel(x: 1, y: 0) == [60])

        let redBlue = try dir.readRasters(window: window, samples: [0, 2], sampleValues: false, interleaveValues: true)
        #expect(redBlue.samplesPerPixel == 2)
        #expect(redBlue.pixel(x: 1, y: 0) == [40, 60])
    }

    @Test func invalidReadArgumentsThrow() {
        let dir = directory(
            width: 2, height: 1, bitsPerSample: [8],
            pixelData: [1, 2], stripOffsets: [0], stripByteCounts: [2]
        )
        let full = ImageWindow(minX: 0, minY: 0, maxX: 2, maxY: 1)
        expectTIFFError(\.isInvalidArgument) {
            _ = try dir.readRasters(window: full, samples: nil, sampleValues: true, interleaveValues: true)
        }
        expectTIFFError(\.isInvalidArgument) {
            _ = try dir.readRasters(window: full, samples: [1], sampleValues: true, interleaveValues: false)
        }
        expectTIFFError(\.isInvalidArgument) {
            _ = try dir.readRasters(window: ImageWindow(minX: 0, minY: 0, maxX: 3, maxY: 1))
        }
        expectTIFFError(\.isInvalidArgument) {
            _ = try dir.readRasters(window: ImageWindow(minX: 1, minY: 0, maxX: 1, maxY: 1))
        }
    }

    // MARK: - Writing

    @Test func dimensionsBeyond16BitsRoundTrip() throws {
        let width = 70_000
        var rasters = TIFFRasters(width: width, height: 1, samplesPerPixel: 1, singleBitsPerSample: 8)
        rasters.setFirstPixelSample(x: width - 1, y: 0, value: 42)

        var dir = writableDirectory(rasters: rasters)
        #expect(dir.entry(for: .imageWidth)?.fieldType == .long)
        #expect(dir.imageWidth == width)
        dir.setRowsPerStrip(100_000)
        #expect(dir.entry(for: .rowsPerStrip)?.fieldType == .long)

        let readBack = try TIFFReader.read(from: TIFFWriter.write(image: TIFFImage(fileDirectory: dir)))
        let rasters2 = try readBack.fileDirectory.readRasters()
        #expect(readBack.fileDirectory.imageWidth == width)
        #expect(rasters2.firstPixelSample(x: width - 1, y: 0) == 42)
    }

    @Test func outOfRangeSampleValueThrows() {
        for value in [300.0, -1.0, .nan] {
            var rasters = TIFFRasters(width: 1, height: 1, samplesPerPixel: 1, singleBitsPerSample: 8)
            rasters.setFirstPixelSample(x: 0, y: 0, value: value)
            let dir = writableDirectory(rasters: rasters)
            expectTIFFError(\.isWriteError) {
                _ = try TIFFWriter.write(image: TIFFImage(fileDirectory: dir))
            }
        }
    }

    @Test func rastersDirectoryMismatchThrows() {
        let rasters = TIFFRasters(width: 2, height: 2, samplesPerPixel: 1, singleBitsPerSample: 8)
        var dir = writableDirectory(rasters: rasters)
        dir.setImageWidth(3)
        expectTIFFError(\.isWriteError) {
            _ = try TIFFWriter.write(image: TIFFImage(fileDirectory: dir))
        }
    }

    @Test func zeroRowsPerStripThrows() {
        let rasters = TIFFRasters(width: 1, height: 1, samplesPerPixel: 1, singleBitsPerSample: 8)
        var dir = writableDirectory(rasters: rasters)
        dir.setRowsPerStrip(0)
        expectTIFFError(\.isWriteError) {
            _ = try TIFFWriter.write(image: TIFFImage(fileDirectory: dir))
        }
    }
}

// MARK: - Helpers

private func entry(_ tag: FieldTagType, _ type: FieldType, _ values: [EntryValue]) -> FileDirectoryEntry {
    FileDirectoryEntry(
        fieldTag: tag, fieldType: type, typeCount: values.count,
        values: values.count == 1 ? values[0] : .array(values)
    )
}

private func baseEntries(width: Int, height: Int, bitsPerSample: [Int]) -> [FieldTagType: FileDirectoryEntry] {
    [
        .imageWidth: entry(.imageWidth, .long, [.long(UInt32(width))]),
        .imageLength: entry(.imageLength, .long, [.long(UInt32(height))]),
        .bitsPerSample: entry(.bitsPerSample, .short, bitsPerSample.map { .short(UInt16($0)) }),
        .samplesPerPixel: entry(.samplesPerPixel, .short, [.short(UInt16(bitsPerSample.count))]),
    ]
}

/// An uncompressed, chunky, stripped directory over in-memory pixel bytes.
private func directory(
    width: Int, height: Int, bitsPerSample: [Int],
    pixelData: [UInt8], stripOffsets: [UInt32], stripByteCounts: [UInt32],
    rowsPerStrip: Int? = nil
) -> TIFFFileDirectory {
    var entries = baseEntries(width: width, height: height, bitsPerSample: bitsPerSample)
    entries[.rowsPerStrip] = entry(.rowsPerStrip, .long, [.long(UInt32(rowsPerStrip ?? height))])
    entries[.stripOffsets] = entry(.stripOffsets, .long, stripOffsets.map { .long($0) })
    entries[.stripByteCounts] = entry(.stripByteCounts, .long, stripByteCounts.map { .long($0) })
    return TIFFFileDirectory(entries: entries, fileData: Data(pixelData), fileByteOrder: .littleEndian)
}

private func writableDirectory(rasters: TIFFRasters) -> TIFFFileDirectory {
    var dir = TIFFFileDirectory(rasters: rasters)
    dir.setImageWidth(rasters.width)
    dir.setImageHeight(rasters.height)
    dir.setBitsPerSample(rasters.bitsPerSample)
    dir.setSamplesPerPixel(rasters.samplesPerPixel)
    dir.setSampleFormatAsSingleValue(.unsignedInt)
    dir.setRowsPerStrip(rasters.height)
    dir.setPlanarConfiguration(.chunky)
    dir.setCompression(.none)
    return dir
}

private func expectTIFFError(
    _ matches: (TIFFError) -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> Void
) {
    let error = #expect(throws: TIFFError.self, sourceLocation: sourceLocation, performing: body)
    if let error, !matches(error) {
        Issue.record("Unexpected TIFFError: \(error)", sourceLocation: sourceLocation)
    }
}

private extension TIFFError {
    var isInvalidData: Bool { if case .invalidData = self { true } else { false } }
    var isInvalidArgument: Bool { if case .invalidArgument = self { true } else { false } }
    var isUnsupported: Bool { if case .unsupported = self { true } else { false } }
    var isUnsupportedPredictor: Bool { if case .unsupportedPredictor = self { true } else { false } }
    var isUnexpectedEndOfData: Bool { if case .unexpectedEndOfData = self { true } else { false } }
    var isWriteError: Bool { if case .writeError = self { true } else { false } }
}
