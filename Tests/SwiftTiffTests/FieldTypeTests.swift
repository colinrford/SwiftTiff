import Testing
@testable import SwiftTiff

struct FieldTypeTests {

    @Test func byteCount() {
        #expect(FieldType.byte.byteCount == 1)
        #expect(FieldType.ascii.byteCount == 1)
        #expect(FieldType.sbyte.byteCount == 1)
        #expect(FieldType.undefined.byteCount == 1)
        #expect(FieldType.short.byteCount == 2)
        #expect(FieldType.sshort.byteCount == 2)
        #expect(FieldType.long.byteCount == 4)
        #expect(FieldType.slong.byteCount == 4)
        #expect(FieldType.float.byteCount == 4)
        #expect(FieldType.rational.byteCount == 8)
        #expect(FieldType.srational.byteCount == 8)
        #expect(FieldType.double.byteCount == 8)
    }

    @Test func fromSampleFormatAndBitsPerSample() throws {
        #expect(try FieldType.from(sampleFormat: .unsignedInt, bitsPerSample: 8) == .byte)
        #expect(try FieldType.from(sampleFormat: .unsignedInt, bitsPerSample: 16) == .short)
        #expect(try FieldType.from(sampleFormat: .unsignedInt, bitsPerSample: 32) == .long)
        #expect(try FieldType.from(sampleFormat: .signedInt, bitsPerSample: 8) == .sbyte)
        #expect(try FieldType.from(sampleFormat: .signedInt, bitsPerSample: 16) == .sshort)
        #expect(try FieldType.from(sampleFormat: .signedInt, bitsPerSample: 32) == .slong)
        #expect(try FieldType.from(sampleFormat: .float, bitsPerSample: 32) == .float)
        #expect(try FieldType.from(sampleFormat: .float, bitsPerSample: 64) == .double)
    }

    @Test func fromInvalidCombinationThrows() {
        #expect(throws: TIFFError.self) {
            try FieldType.from(sampleFormat: .unsignedInt, bitsPerSample: 64)
        }
        #expect(throws: TIFFError.self) {
            try FieldType.from(sampleFormat: .float, bitsPerSample: 8)
        }
    }

    @Test func sampleFormat() throws {
        #expect(try FieldType.byte.sampleFormat == .unsignedInt)
        #expect(try FieldType.short.sampleFormat == .unsignedInt)
        #expect(try FieldType.long.sampleFormat == .unsignedInt)
        #expect(try FieldType.sbyte.sampleFormat == .signedInt)
        #expect(try FieldType.sshort.sampleFormat == .signedInt)
        #expect(try FieldType.slong.sampleFormat == .signedInt)
        #expect(try FieldType.float.sampleFormat == .float)
        #expect(try FieldType.double.sampleFormat == .float)
    }

    @Test func sampleFormatThrowsForNonNumeric() {
        #expect(throws: TIFFError.self) {
            try FieldType.ascii.sampleFormat
        }
        #expect(throws: TIFFError.self) {
            try FieldType.rational.sampleFormat
        }
    }

    @Test func rawValues() {
        #expect(FieldType.byte.rawValue == 1)
        #expect(FieldType.double.rawValue == 12)
        #expect(FieldType(rawValue: 1) == .byte)
        #expect(FieldType(rawValue: 99) == nil)
    }
}
