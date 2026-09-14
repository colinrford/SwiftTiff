import Testing
import Foundation
@testable import SwiftTiff

struct CompressionCodecTests {

    // MARK: - Factory function

    @Test func codecForSupportedTypes() throws {
        let raw = try codec(for: .none)
        #expect(raw is RawCodec)

        let lzw = try codec(for: .lzw)
        #expect(lzw is LZWCodec)

        let packbits = try codec(for: .packbits)
        #expect(packbits is PackbitsCodec)

        let deflate = try codec(for: .deflate)
        #expect(deflate is DeflateCodec)
    }

    @Test func codecForUnsupportedTypesThrows() {
        #expect(throws: TIFFError.self) {
            try codec(for: .ccittHuffman)
        }
        #expect(throws: TIFFError.self) {
            try codec(for: .t4)
        }
        #expect(throws: TIFFError.self) {
            try codec(for: .t6)
        }
        #expect(throws: TIFFError.self) {
            try codec(for: .jpegOld)
        }
        #expect(throws: TIFFError.self) {
            try codec(for: .jpegNew)
        }
    }

    // MARK: - RawCodec

    @Test func rawCodecPassthrough() throws {
        let raw = RawCodec()
        let input = Data([0x01, 0x02, 0x03, 0x04])
        let decoded = try raw.decode(input, byteOrder: .bigEndian)
        #expect(decoded == input)
        let encoded = try raw.encode(input, byteOrder: .bigEndian)
        #expect(encoded == input)
        #expect(raw.rowEncoding == false)
    }

    // MARK: - DeflateCodec

    @Test func deflateCodecThrows() {
        let deflate = DeflateCodec()
        #expect(throws: TIFFError.self) {
            try deflate.decode(Data(), byteOrder: .bigEndian)
        }
        #expect(throws: TIFFError.self) {
            try deflate.encode(Data(), byteOrder: .bigEndian)
        }
        #expect(deflate.rowEncoding == false)
    }

    // MARK: - PackbitsCodec

    @Test func packbitsRowEncoding() {
        #expect(PackbitsCodec().rowEncoding == true)
    }

    @Test func packbitsDecodeLiteral() throws {
        // Header 0x02 = copy next 3 bytes literally
        let input = Data([0x02, 0xAA, 0xBB, 0xCC])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0xAA, 0xBB, 0xCC]))
    }

    @Test func packbitsDecodeRun() throws {
        // Header 0xFE (-2 as Int8) = repeat next byte 3 times
        let input = Data([0xFE, 0xAA])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0xAA, 0xAA, 0xAA]))
    }

    @Test func packbitsDecodeNoop() throws {
        // Header 0x80 (-128) = no-op, then literal 0x00 = copy 1 byte
        let input = Data([0x80, 0x00, 0x42])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0x42]))
    }

    @Test func packbitsDecodeSlice() throws {
        // Slice with non-zero startIndex: literal 0x02 → copy 3 bytes
        let parent = Data([0xEE, 0xEE, 0x02, 0xAA, 0xBB, 0xCC])
        let decoded = try PackbitsCodec().decode(parent[2...], byteOrder: .bigEndian)
        #expect(decoded == Data([0xAA, 0xBB, 0xCC]))
    }

    @Test func packbitsDecodeMixed() throws {
        // Literal: 0x01 → copy 2 bytes [0xAA, 0xBB]
        // Run: 0xFD (-3) → repeat 0xCC 4 times
        let input = Data([0x01, 0xAA, 0xBB, 0xFD, 0xCC])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0xAA, 0xBB, 0xCC, 0xCC, 0xCC, 0xCC]))
    }

    @Test func packbitsDecodeEmpty() throws {
        let decoded = try PackbitsCodec().decode(Data(), byteOrder: .bigEndian)
        #expect(decoded == Data())
    }

    @Test func packbitsEncodeThrows() {
        #expect(throws: TIFFError.self) {
            try PackbitsCodec().encode(Data([0x01]), byteOrder: .bigEndian)
        }
    }

    @Test func packbitsDecodeRealTiffStrip() throws {
        // Decode strip 0 from packbits.tiff (539px * 15spp * 16bps = 16170 bytes)
        let url = Bundle.module.url(forResource: "packbits", withExtension: "tiff", subdirectory: "Resources")!
        let fileData = try Data(contentsOf: url)

        // Strip 0: offset=4190, length=254
        let compressed = fileData[4190..<(4190 + 254)]
        let decoded = try PackbitsCodec().decode(compressed, byteOrder: .littleEndian)
        #expect(decoded.count == 16170)
        #expect(decoded.allSatisfy { $0 == 0 })
    }

    // MARK: - LZWCodec

    @Test func lzwRowEncoding() {
        #expect(LZWCodec().rowEncoding == false)
    }

    @Test func lzwDecodeSimple() throws {
        // Manually construct a minimal LZW stream:
        // Clear(256), 'A'(65), 'B'(66), 'A'(65), EOI(257)
        // At 9-bit codes:
        //   256 = 1_0000_0000
        //   65  = 0_0100_0001
        //   66  = 0_0100_0010
        //   65  = 0_0100_0001
        //   257 = 1_0000_0001
        // Bit stream: 100000000 001000001 001000010 001000001 100000001
        // = 0x80 0x10 0x48 0x44 0x18 0x08
        let input = Data([0x80, 0x10, 0x48, 0x44, 0x18, 0x08])
        let decoded = try LZWCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0x41, 0x42, 0x41])) // "ABA"
    }

    @Test func lzwDecodeSlice() throws {
        // Same stream as lzwDecodeSimple, inside a slice with non-zero startIndex
        let parent = Data([0xEE, 0xEE, 0x80, 0x10, 0x48, 0x44, 0x18, 0x08])
        let decoded = try LZWCodec().decode(parent[2...], byteOrder: .bigEndian)
        #expect(decoded == Data([0x41, 0x42, 0x41])) // "ABA"
    }

    @Test func lzwDecodeWithTableEntry() throws {
        // Clear(256), 'A'(65), 'B'(66), 258(="AB"), EOI(257)
        // After reading A then B, table entry 258 = "AB"
        // Reading code 258 outputs "AB"
        // 9-bit codes:
        //   256 = 100000000
        //   65  = 001000001
        //   66  = 001000010
        //   258 = 100000010
        //   257 = 100000001
        // Bits: 100000000 001000001 001000010 100000010 100000001
        // Bytes: 0x80 0x10 0x48 0x50 0x28 0x08
        let input = Data([0x80, 0x10, 0x48, 0x50, 0x28, 0x08])
        let decoded = try LZWCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0x41, 0x42, 0x41, 0x42])) // "ABAB"
    }

    @Test func lzwDecodeEmpty() throws {
        // Clear(256), EOI(257) at 9-bit codes:
        //   256 = 100000000
        //   257 = 100000001
        // Bits: 100000000 100000001
        // Bytes: 0x80 0x40 0x40
        let input = Data([0x80, 0x40, 0x40])
        let decoded = try LZWCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data())
    }

    @Test func lzwDecodeNotInTable() throws {
        // The "code not in table" special case:
        // Clear(256), A(65), 258, EOI(257)
        // After clear+A: old=65, table has 0-257
        // Code 258 is NOT in table → new_entry = table[65] + table[65][0] = "AA"
        // Output: "A" + "AA" = "AAA"
        // 9-bit codes: 100000000 001000001 100000010 100000001
        let input = Data([0x80, 0x10, 0x60, 0x50, 0x10])
        let decoded = try LZWCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0x41, 0x41, 0x41])) // "AAA"
    }

    @Test func lzwDecodeConsecutiveClearCodes() throws {
        // Clear(256), Clear(256), Clear(256), A(65), EOI(257)
        // Multiple clear codes should be skipped, output just "A"
        let input = Data([0x80, 0x40, 0x20, 0x04, 0x18, 0x08])
        let decoded = try LZWCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0x41]))
    }

    @Test func lzwDecodeCorruptedAfterClear() {
        // Clear(256), 258 — code 258 > CLEAR_CODE after reset, should throw
        // 9-bit codes: 100000000 100000010
        let input = Data([0x80, 0x40, 0x80])
        #expect(throws: TIFFError.self) {
            try LZWCodec().decode(input, byteOrder: .bigEndian)
        }
    }

    @Test func lzwDecodeRealTiffStrip() throws {
        // Decode strip 1 from lzw.tiff (309 bytes compressed, reaches 10-bit codes)
        let url = Bundle.module.url(forResource: "lzw", withExtension: "tiff", subdirectory: "Resources")!
        let fileData = try Data(contentsOf: url)

        // Strip 1: offset=4407, length=309 (little-endian TIFF, 539px * 15spp * 2bps = 16170 decoded)
        let compressed = fileData[4407..<(4407 + 309)]
        let decoded = try LZWCodec().decode(compressed, byteOrder: .littleEndian)
        #expect(decoded.count == 16170)

        // Verify it's not all zeros (strip 1 has non-zero pixel data)
        let nonZeroCount = decoded.filter { $0 != 0 }.count
        #expect(nonZeroCount > 0)
    }

    @Test func lzwEncodeThrows() {
        #expect(throws: TIFFError.self) {
            try LZWCodec().encode(Data([0x01]), byteOrder: .bigEndian)
        }
    }

    // MARK: - PackBits boundary cases

    @Test func packbitsDecodeMaxLiteral() throws {
        // Header 0x7F (127) = copy next 128 bytes literally (max literal run)
        var input = Data([0x7F])
        let literalBytes = Data(0..<128)
        input.append(literalBytes)
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == literalBytes)
    }

    @Test func packbitsDecodeMinRun() throws {
        // Header 0xFF (-1 as Int8) = repeat next byte 2 times (minimum run)
        let input = Data([0xFF, 0xAB])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded == Data([0xAB, 0xAB]))
    }

    @Test func packbitsDecodeMaxRun() throws {
        // Header 0x81 (-127 as Int8) = repeat next byte 128 times (maximum run)
        let input = Data([0x81, 0x42])
        let decoded = try PackbitsCodec().decode(input, byteOrder: .bigEndian)
        #expect(decoded.count == 128)
        #expect(decoded.allSatisfy { $0 == 0x42 })
    }
}
