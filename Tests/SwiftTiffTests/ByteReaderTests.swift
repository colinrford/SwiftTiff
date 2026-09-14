import Testing
import Foundation
@testable import SwiftTiff

struct ByteReaderTests {

    // MARK: - Sequential reads, big endian

    @Test func readUInt8BigEndian() throws {
        var reader = ByteReader(data: Data([0xAB]), byteOrder: .bigEndian)
        #expect(try reader.readUInt8() == 0xAB)
        #expect(reader.position == 1)
    }

    @Test func readUInt16BigEndian() throws {
        var reader = ByteReader(data: Data([0x01, 0x02]), byteOrder: .bigEndian)
        #expect(try reader.readUInt16() == 0x0102)
        #expect(reader.position == 2)
    }

    @Test func readUInt32BigEndian() throws {
        var reader = ByteReader(data: Data([0x00, 0x00, 0x00, 0x2A]), byteOrder: .bigEndian)
        #expect(try reader.readUInt32() == 42)
        #expect(reader.position == 4)
    }

    @Test func readInt16BigEndian() throws {
        // -1 in big endian = 0xFF 0xFF
        var reader = ByteReader(data: Data([0xFF, 0xFF]), byteOrder: .bigEndian)
        #expect(try reader.readInt16() == -1)
    }

    @Test func readInt32BigEndian() throws {
        // -1 in big endian = 0xFF 0xFF 0xFF 0xFF
        var reader = ByteReader(data: Data([0xFF, 0xFF, 0xFF, 0xFF]), byteOrder: .bigEndian)
        #expect(try reader.readInt32() == -1)
    }

    @Test func readFloat32BigEndian() throws {
        // 1.0f = 0x3F800000 in IEEE 754
        var reader = ByteReader(data: Data([0x3F, 0x80, 0x00, 0x00]), byteOrder: .bigEndian)
        #expect(try reader.readFloat32() == 1.0)
    }

    @Test func readFloat64BigEndian() throws {
        // 1.0 = 0x3FF0000000000000 in IEEE 754
        var reader = ByteReader(
            data: Data([0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            byteOrder: .bigEndian
        )
        #expect(try reader.readFloat64() == 1.0)
    }

    // MARK: - Sequential reads, little endian

    @Test func readUInt16LittleEndian() throws {
        var reader = ByteReader(data: Data([0x02, 0x01]), byteOrder: .littleEndian)
        #expect(try reader.readUInt16() == 0x0102)
    }

    @Test func readUInt32LittleEndian() throws {
        var reader = ByteReader(data: Data([0x2A, 0x00, 0x00, 0x00]), byteOrder: .littleEndian)
        #expect(try reader.readUInt32() == 42)
    }

    @Test func readFloat32LittleEndian() throws {
        // 1.0f = 0x3F800000, little endian = 00 00 80 3F
        var reader = ByteReader(data: Data([0x00, 0x00, 0x80, 0x3F]), byteOrder: .littleEndian)
        #expect(try reader.readFloat32() == 1.0)
    }

    @Test func readFloat64LittleEndian() throws {
        // 1.0 = 0x3FF0000000000000, little endian = 00 00 00 00 00 00 F0 3F
        var reader = ByteReader(
            data: Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]),
            byteOrder: .littleEndian
        )
        #expect(try reader.readFloat64() == 1.0)
    }

    // MARK: - Random-access reads

    @Test func readAtOffset() throws {
        let reader = ByteReader(data: Data([0x00, 0x00, 0x2A]), byteOrder: .bigEndian)
        #expect(try reader.readUInt8(at: 2) == 0x2A)
        #expect(reader.position == 0) // position unchanged
    }

    @Test func readUInt16AtOffset() throws {
        let reader = ByteReader(data: Data([0xFF, 0x01, 0x02]), byteOrder: .bigEndian)
        #expect(try reader.readUInt16(at: 1) == 0x0102)
        #expect(reader.position == 0)
    }

    // MARK: - String and bytes

    @Test func readString() throws {
        var reader = ByteReader(data: Data("II".utf8), byteOrder: .bigEndian)
        #expect(try reader.readString(2) == "II")
        #expect(reader.position == 2)
    }

    @Test func readBytes() throws {
        var reader = ByteReader(data: Data([0x01, 0x02, 0x03]), byteOrder: .bigEndian)
        let bytes = try reader.readBytes(2)
        #expect(bytes == Data([0x01, 0x02]))
        #expect(reader.position == 2)
    }

    // MARK: - Bounds checking

    @Test func readBeyondEndThrows() {
        var reader = ByteReader(data: Data([0x01]), byteOrder: .bigEndian)
        #expect(throws: TIFFError.self) {
            try reader.readUInt16()
        }
    }

    @Test func readAtOffsetBeyondEndThrows() {
        let reader = ByteReader(data: Data([0x01]), byteOrder: .bigEndian)
        #expect(throws: TIFFError.self) {
            try reader.readUInt8(at: 1)
        }
    }

    // MARK: - Sliced input

    @Test func readFromSliceUsesZeroBasedOffsets() throws {
        // A slice keeps its parent's indices (startIndex == 2 here)
        let parent = Data([0xEE, 0xEE, 0x01, 0x02, 0x03, 0x04, 0x05])
        var reader = ByteReader(data: parent[2...], byteOrder: .bigEndian)
        #expect(reader.byteLength == 5)
        #expect(try reader.readUInt8() == 0x01)
        #expect(try reader.readBytes(2) == Data([0x02, 0x03]))
        #expect(try reader.readUInt8(at: 0) == 0x01)
        #expect(try reader.readUInt16(at: 3) == 0x0405)
        #expect(try reader.readBytes(at: 3, count: 2) == Data([0x04, 0x05]))
        #expect(throws: TIFFError.self) {
            try reader.readUInt8(at: 5)
        }
    }

    // MARK: - State

    @Test func remainingBytes() throws {
        var reader = ByteReader(data: Data([0x01, 0x02, 0x03]), byteOrder: .bigEndian)
        #expect(reader.remainingBytes == 3)
        #expect(reader.hasRemaining == true)
        _ = try reader.readUInt8()
        #expect(reader.remainingBytes == 2)
        _ = try reader.readBytes(2)
        #expect(reader.remainingBytes == 0)
        #expect(reader.hasRemaining == false)
    }

    @Test func byteLength() {
        let reader = ByteReader(data: Data([0x01, 0x02, 0x03]), byteOrder: .bigEndian)
        #expect(reader.byteLength == 3)
    }

    // MARK: - Sequential multi-read

    @Test func sequentialReads() throws {
        // Read a mini TIFF header: "MM" + 42 + offset
        var reader = ByteReader(
            data: Data([0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08]),
            byteOrder: .bigEndian
        )
        let marker = try reader.readString(2)
        #expect(marker == "MM")
        let magic = try reader.readUInt16()
        #expect(magic == 42)
        let offset = try reader.readUInt32()
        #expect(offset == 8)
        #expect(reader.position == 8)
    }

    // MARK: - Factory methods

    @Test func fromFile() throws {
        let bundle = Bundle.module
        let path = bundle.path(forResource: "small", ofType: "tiff", inDirectory: "Fixtures")!
        let reader = try ByteReader.from(file: path)
        #expect(reader.byteLength > 0)
        #expect(reader.position == 0)
    }

    @Test func fromStream() throws {
        let bundle = Bundle.module
        let path = bundle.path(forResource: "small", ofType: "tiff", inDirectory: "Fixtures")!
        let stream = InputStream(fileAtPath: path)!
        let reader = try ByteReader.from(stream: stream)
        #expect(reader.byteLength > 0)
        #expect(reader.position == 0)
    }

    @Test func fromFileAndStreamProduceSameData() throws {
        let bundle = Bundle.module
        let path = bundle.path(forResource: "small", ofType: "tiff", inDirectory: "Fixtures")!
        let fromFile = try ByteReader.from(file: path)
        let stream = InputStream(fileAtPath: path)!
        let fromStream = try ByteReader.from(stream: stream)
        #expect(fromFile.data == fromStream.data)
    }
}
