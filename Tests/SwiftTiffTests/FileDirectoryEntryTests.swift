import Testing
import Foundation
@testable import SwiftTiff

struct FileDirectoryEntryTests {

    // MARK: - Construction

    @Test func basicConstruction() {
        let entry = FileDirectoryEntry(
            fieldTag: .imageWidth,
            fieldType: .short,
            typeCount: 1,
            values: .short(256)
        )
        #expect(entry.fieldTag == .imageWidth)
        #expect(entry.fieldType == .short)
        #expect(entry.typeCount == 1)
        #expect(entry.values == .short(256))
    }

    // MARK: - Size calculations

    @Test func sizeOfValuesInline() {
        // 1 short = 2 bytes, fits in 4-byte inline space
        let entry = FileDirectoryEntry(
            fieldTag: .imageWidth,
            fieldType: .short,
            typeCount: 1,
            values: .short(256)
        )
        #expect(entry.sizeOfValues == 0)
        #expect(entry.sizeWithValues == 12) // just the IFD entry
    }

    @Test func sizeOfValuesFourBytesInline() {
        // 2 shorts = 4 bytes, still fits inline
        let entry = FileDirectoryEntry(
            fieldTag: .bitsPerSample,
            fieldType: .short,
            typeCount: 2,
            values: .array([.short(8), .short(8)])
        )
        #expect(entry.sizeOfValues == 0)
        #expect(entry.sizeWithValues == 12)
    }

    @Test func sizeOfValuesOverflow() {
        // 3 shorts = 6 bytes, overflows 4-byte inline space
        let entry = FileDirectoryEntry(
            fieldTag: .bitsPerSample,
            fieldType: .short,
            typeCount: 3,
            values: .array([.short(8), .short(8), .short(8)])
        )
        #expect(entry.sizeOfValues == 6)
        #expect(entry.sizeWithValues == 18) // 12 + 6
    }

    @Test func sizeOfLongValues() {
        // 1 long = 4 bytes, fits inline
        let entryInline = FileDirectoryEntry(
            fieldTag: .imageWidth,
            fieldType: .long,
            typeCount: 1,
            values: .long(1024)
        )
        #expect(entryInline.sizeOfValues == 0)

        // 2 longs = 8 bytes, overflows
        let entryOverflow = FileDirectoryEntry(
            fieldTag: .stripOffsets,
            fieldType: .long,
            typeCount: 2,
            values: .array([.long(8), .long(1024)])
        )
        #expect(entryOverflow.sizeOfValues == 8)
    }

    @Test func sizeOfRationalValues() {
        // 1 rational = 8 bytes, always overflows
        let entry = FileDirectoryEntry(
            fieldTag: .xResolution,
            fieldType: .rational,
            typeCount: 1,
            values: .rational(numerator: 72, denominator: 1)
        )
        #expect(entry.sizeOfValues == 8)
        #expect(entry.sizeWithValues == 20)
    }

    // MARK: - EntryValue

    @Test func entryValueEquality() {
        #expect(EntryValue.byte(42) == EntryValue.byte(42))
        #expect(EntryValue.byte(42) != EntryValue.byte(43))
        #expect(EntryValue.ascii("hello") == EntryValue.ascii("hello"))
        #expect(EntryValue.short(256) == EntryValue.short(256))
        #expect(EntryValue.long(100_000) == EntryValue.long(100_000))
        #expect(EntryValue.rational(numerator: 72, denominator: 1)
                == EntryValue.rational(numerator: 72, denominator: 1))
        #expect(EntryValue.rational(numerator: 72, denominator: 1)
                != EntryValue.rational(numerator: 72, denominator: 2))
        #expect(EntryValue.float(3.14) == EntryValue.float(3.14))
        #expect(EntryValue.double(2.71828) == EntryValue.double(2.71828))
    }

    @Test func entryValueArray() {
        let arr = EntryValue.array([.short(8), .short(8), .short(8)])
        if case .array(let values) = arr {
            #expect(values.count == 3)
            #expect(values[0] == .short(8))
        } else {
            Issue.record("Expected .array case")
        }
    }

    @Test func entryValueTypes() {
        // Verify all cases can be constructed
        let _ = EntryValue.byte(0xFF)
        let _ = EntryValue.ascii("test")
        let _ = EntryValue.short(0xFFFF)
        let _ = EntryValue.long(0xFFFFFFFF)
        let _ = EntryValue.rational(numerator: 1, denominator: 2)
        let _ = EntryValue.sbyte(-1)
        let _ = EntryValue.undefined(Data([0x00, 0x01]))
        let _ = EntryValue.sshort(-1000)
        let _ = EntryValue.slong(-100_000)
        let _ = EntryValue.srational(numerator: -1, denominator: 2)
        let _ = EntryValue.float(1.5)
        let _ = EntryValue.double(1.5)
    }
}
