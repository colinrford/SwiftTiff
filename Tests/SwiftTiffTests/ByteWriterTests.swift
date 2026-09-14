import Testing
import Foundation
@testable import SwiftTiff

struct ByteWriterTests {

    // MARK: - Big endian writes

    @Test func writeUInt8() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeUInt8(0xAB)
        #expect(writer.data == Data([0xAB]))
        #expect(writer.count == 1)
    }

    @Test func writeUInt16BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeUInt16(0x0102)
        #expect(writer.data == Data([0x01, 0x02]))
    }

    @Test func writeUInt32BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeUInt32(42)
        #expect(writer.data == Data([0x00, 0x00, 0x00, 0x2A]))
    }

    @Test func writeFloat32BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeFloat32(1.0)
        #expect(writer.data == Data([0x3F, 0x80, 0x00, 0x00]))
    }

    @Test func writeFloat64BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeFloat64(1.0)
        #expect(writer.data == Data([0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    // MARK: - Little endian writes

    @Test func writeUInt16LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeUInt16(0x0102)
        #expect(writer.data == Data([0x02, 0x01]))
    }

    @Test func writeUInt32LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeUInt32(42)
        #expect(writer.data == Data([0x2A, 0x00, 0x00, 0x00]))
    }

    // MARK: - Signed writes

    @Test func writeInt8() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeInt8(-1)
        #expect(writer.data == Data([0xFF]))
    }

    @Test func writeInt16BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeInt16(-1)
        #expect(writer.data == Data([0xFF, 0xFF]))
    }

    @Test func writeInt32BigEndian() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeInt32(-1)
        #expect(writer.data == Data([0xFF, 0xFF, 0xFF, 0xFF]))
    }

    // MARK: - Bytes and strings

    @Test func writeBytes() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        writer.writeBytes(Data([0x01, 0x02, 0x03]))
        #expect(writer.data == Data([0x01, 0x02, 0x03]))
        #expect(writer.count == 3) // Verifies ObjC bug is fixed
    }

    @Test func writeString() {
        var writer = ByteWriter(byteOrder: .bigEndian)
        let bytesWritten = writer.writeString("MM")
        #expect(bytesWritten == 2)
        #expect(writer.data == Data([0x4D, 0x4D]))
    }

    @Test func writeInt16LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeInt16(-256) // 0xFF00 in two's complement = 0x00, 0xFF in LE
        #expect(writer.data == Data([0x00, 0xFF]))
    }

    @Test func writeInt32LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeInt32(-1) // 0xFFFFFFFF
        #expect(writer.data == Data([0xFF, 0xFF, 0xFF, 0xFF]))
    }

    @Test func writeFloat32LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeFloat32(1.0) // IEEE 754: 0x3F800000 → LE: 0x00, 0x00, 0x80, 0x3F
        #expect(writer.data == Data([0x00, 0x00, 0x80, 0x3F]))
    }

    @Test func writeFloat64LittleEndian() {
        var writer = ByteWriter(byteOrder: .littleEndian)
        writer.writeFloat64(1.0) // IEEE 754: 0x3FF0000000000000 → LE: 0x00..0x00, 0xF0, 0x3F
        #expect(writer.data == Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x3F]))
    }

    // MARK: - Round-trip with ByteReader

    @Test func roundTripAllTypes() throws {
        for order in [ByteOrder.bigEndian, .littleEndian] {
            var writer = ByteWriter(byteOrder: order)
            writer.writeUInt8(0xAB)
            writer.writeInt8(-42)
            writer.writeUInt16(1000)
            writer.writeInt16(-1000)
            writer.writeUInt32(100_000)
            writer.writeInt32(-100_000)
            writer.writeFloat32(3.14)
            writer.writeFloat64(2.71828)

            var reader = ByteReader(data: writer.data, byteOrder: order)
            #expect(try reader.readUInt8() == 0xAB)
            #expect(try reader.readInt8() == -42)
            #expect(try reader.readUInt16() == 1000)
            #expect(try reader.readInt16() == -1000)
            #expect(try reader.readUInt32() == 100_000)
            #expect(try reader.readInt32() == -100_000)
            #expect(try reader.readFloat32() == 3.14 as Float)
            #expect(try reader.readFloat64() == 2.71828)
            #expect(reader.hasRemaining == false)
        }
    }

    // MARK: - TIFF header round-trip

    @Test func tiffHeaderRoundTrip() throws {
        var writer = ByteWriter(byteOrder: .bigEndian)
        _ = writer.writeString("MM")
        writer.writeUInt16(42)
        writer.writeUInt32(8)

        var reader = ByteReader(data: writer.data, byteOrder: .bigEndian)
        #expect(try reader.readString(2) == "MM")
        #expect(try reader.readUInt16() == 42)
        #expect(try reader.readUInt32() == 8)
    }
}
