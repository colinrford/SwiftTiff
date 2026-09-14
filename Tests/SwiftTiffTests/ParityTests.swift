import Foundation
import Testing
import CryptoKit
@testable import SwiftTiff

/// Parity tests: verify Swift decode output against pre-recorded golden JSON.
///
/// Phase 1 validates the driver machinery using a single fixture
/// (`stripped.tiff`) with a golden bootstrapped from Swift itself.
/// Phase 2 will parametrize across all fixtures once the ObjC generator
/// exists.
@Suite struct ParityTests {

    @Test func strippedMatchesGolden() throws {
        try runParity(fixture: "stripped")
    }
}

// MARK: - Driver

private func runParity(fixture: String) throws {
    let golden = try loadGolden(fixture: fixture)
    let tiffURL = try locateFixture(fixture)
    let tiff = try TIFFReader.read(fromFile: tiffURL.path)

    #expect(
        tiff.fileDirectories.count == golden.images.count,
        "\(fixture): IFD count mismatch (expected \(golden.images.count), got \(tiff.fileDirectories.count))"
    )

    for expected in golden.images {
        let actual = tiff.fileDirectories[expected.index]
        compareDirectory(actual, expected.directory, fixture: fixture, index: expected.index)

        let rasters = try actual.readRasters()
        compareRasters(rasters, actual: actual, expected: expected.rasters, fixture: fixture, index: expected.index)
    }
}

// MARK: - Directory comparison

private func compareDirectory(
    _ actual: TIFFFileDirectory,
    _ expected: GoldenDirectory,
    fixture: String,
    index: Int
) {
    let tag = "\(fixture)[\(index)]"

    #expect(actual.imageWidth == expected.width, "\(tag) width")
    #expect(actual.imageHeight == expected.height, "\(tag) height")
    #expect((actual.bitsPerSample ?? []) == expected.bitsPerSample, "\(tag) bitsPerSample")
    #expect(actual.samplesPerPixel == expected.samplesPerPixel, "\(tag) samplesPerPixel")
    #expect(Int(actual.compression?.rawValue ?? 1) == expected.compression, "\(tag) compression")
    #expect(
        Int(actual.photometricInterpretation?.rawValue ?? 0) == expected.photometricInterpretation,
        "\(tag) photometricInterpretation"
    )
    #expect(
        Int(actual.planarConfig.rawValue) == expected.planarConfiguration,
        "\(tag) planarConfiguration"
    )
    #expect(actual.rowsPerStrip == expected.rowsPerStrip, "\(tag) rowsPerStrip")
    #expect(actual.tileWidth == expected.tileWidth, "\(tag) tileWidth")
    #expect(actual.tileHeight == expected.tileHeight, "\(tag) tileHeight")
    #expect(actual.stripOffsets == expected.stripOffsets, "\(tag) stripOffsets")
    #expect(actual.stripByteCounts == expected.stripByteCounts, "\(tag) stripByteCounts")

    let actualEntries = actual.sortedEntries.map(goldenEntry(from:))
    #expect(actualEntries.count == expected.entries.count, "\(tag) entry count")

    let byTag = Dictionary(uniqueKeysWithValues: actualEntries.map { ($0.tag, $0) })
    for entry in expected.entries {
        guard let got = byTag[entry.tag] else {
            Issue.record("\(tag) missing entry for tag \(entry.tag)")
            continue
        }
        #expect(got.type == entry.type, "\(tag) tag \(entry.tag) type")
        #expect(got.values == entry.values, "\(tag) tag \(entry.tag) values")
    }
}

// MARK: - Rasters comparison

private func compareRasters(
    _ rasters: TIFFRasters,
    actual: TIFFFileDirectory,
    expected: GoldenRasters,
    fixture: String,
    index: Int
) {
    let tag = "\(fixture)[\(index)]"
    let samples = rasters.samplesPerPixel

    #expect(
        expected.sha256PerSample.count == samples,
        "\(tag) sha256PerSample length (expected \(samples), got \(expected.sha256PerSample.count))"
    )

    let sampleFormats = actual.sampleFormat ?? Array(repeating: 1, count: samples)

    for s in 0..<min(samples, expected.sha256PerSample.count) {
        let bytes = canonicalSampleBytes(
            rasters: rasters,
            sample: s,
            bitsPerSample: rasters.bitsPerSample[s],
            sampleFormat: sampleFormats[s]
        )
        let digest = SHA256.hash(data: bytes)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(
            hex == expected.sha256PerSample[s],
            "\(tag) sha256 sample \(s) (expected \(expected.sha256PerSample[s]), got \(hex))"
        )
    }

    for check in expected.spotChecks {
        let got = rasters.pixelSample(sample: check.sample, x: check.x, y: check.y)
        #expect(
            got == check.value,
            "\(tag) spot (\(check.x),\(check.y),sample=\(check.sample)) expected \(check.value), got \(got)"
        )
    }
}

// MARK: - Canonical byte encoding

/// Serialize one sample plane to little-endian bytes at its declared bit
/// depth. Basis for SHA-256 hashing — stable across platforms and across
/// refactors of `TIFFRasters`' in-memory representation.
private func canonicalSampleBytes(
    rasters: TIFFRasters,
    sample: Int,
    bitsPerSample: Int,
    sampleFormat: Int
) -> Data {
    let width = rasters.width
    let height = rasters.height
    var data = Data()
    data.reserveCapacity(width * height * (bitsPerSample / 8))

    for y in 0..<height {
        for x in 0..<width {
            let value = rasters.pixelSample(sample: sample, x: x, y: y)
            appendCanonical(
                &data,
                value: value,
                bitsPerSample: bitsPerSample,
                sampleFormat: sampleFormat
            )
        }
    }
    return data
}

private func appendCanonical(
    _ data: inout Data,
    value: Double,
    bitsPerSample: Int,
    sampleFormat: Int
) {
    // sampleFormat: 1=unsignedInt, 2=signedInt, 3=float, 4=undefined (treated as unsignedInt)
    switch (sampleFormat, bitsPerSample) {
    case (3, 32):
        appendLE(&data, UInt32(bitPattern: Int32(bitPattern: Float(value).bitPattern)))
    case (3, 64):
        appendLE(&data, value.bitPattern)
    case (2, 8):
        data.append(UInt8(bitPattern: Int8(value)))
    case (2, 16):
        appendLE(&data, UInt16(bitPattern: Int16(value)))
    case (2, 32):
        appendLE(&data, UInt32(bitPattern: Int32(value)))
    case (_, 8):
        data.append(UInt8(value))
    case (_, 16):
        appendLE(&data, UInt16(value))
    case (_, 32):
        appendLE(&data, UInt32(value))
    default:
        fatalError("unsupported (sampleFormat=\(sampleFormat), bitsPerSample=\(bitsPerSample))")
    }
}

private func appendLE(_ data: inout Data, _ v: UInt16) {
    data.append(UInt8(v & 0xFF))
    data.append(UInt8((v >> 8) & 0xFF))
}

private func appendLE(_ data: inout Data, _ v: UInt32) {
    data.append(UInt8(v & 0xFF))
    data.append(UInt8((v >> 8) & 0xFF))
    data.append(UInt8((v >> 16) & 0xFF))
    data.append(UInt8((v >> 24) & 0xFF))
}

private func appendLE(_ data: inout Data, _ v: UInt64) {
    for i in 0..<8 {
        data.append(UInt8((v >> (i * 8)) & 0xFF))
    }
}

// MARK: - Entry conversion

private func goldenEntry(from entry: FileDirectoryEntry) -> GoldenEntry {
    GoldenEntry(
        tag: Int(entry.fieldTag.rawValue),
        type: Int(entry.fieldType.rawValue),
        values: goldenValues(from: entry.values, fieldType: entry.fieldType)
    )
}

/// Flatten an `EntryValue` into a `GoldenValues`.
///
/// Rationals and signed rationals are emitted as `[num, den, ...]` integer
/// pairs — the reader's typed structure is validated by exact-equality
/// comparison with the golden's identically-flattened list.
private func goldenValues(from value: EntryValue, fieldType: FieldType) -> GoldenValues {
    var ints = [Int]()
    var doubles = [Double]()
    var strings = [String]()

    func walk(_ v: EntryValue) {
        switch v {
        case .byte(let x): ints.append(Int(x))
        case .sbyte(let x): ints.append(Int(x))
        case .short(let x): ints.append(Int(x))
        case .sshort(let x): ints.append(Int(x))
        case .long(let x): ints.append(Int(x))
        case .slong(let x): ints.append(Int(x))
        case .rational(let n, let d): ints.append(Int(n)); ints.append(Int(d))
        case .srational(let n, let d): ints.append(Int(n)); ints.append(Int(d))
        case .float(let x): doubles.append(Double(x))
        case .double(let x): doubles.append(x)
        case .ascii(let s): strings.append(s)
        case .undefined(let d): ints.append(contentsOf: d.map { Int($0) })
        case .array(let arr): arr.forEach(walk)
        }
    }
    walk(value)

    switch fieldType {
    case .float, .double:
        return .doubles(doubles)
    case .ascii:
        return .strings(strings)
    default:
        return .ints(ints)
    }
}

// MARK: - Resource loading

private func loadGolden(fixture: String) throws -> Golden {
    let url = try locateGolden(fixture: fixture)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Golden.self, from: data)
}

private func locateFixture(_ fixture: String) throws -> URL {
    guard let url = Bundle.module.url(
        forResource: fixture,
        withExtension: "tiff",
        subdirectory: "Resources"
    ) ?? Bundle.module.url(forResource: fixture, withExtension: "tiff") else {
        throw ParityError.missingResource("\(fixture).tiff")
    }
    return url
}

private func locateGolden(fixture: String) throws -> URL {
    let name = "\(fixture).tiff"
    guard let url = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Goldens"
    ) ?? Bundle.module.url(forResource: name, withExtension: "json") else {
        throw ParityError.missingResource("Goldens/\(name).json")
    }
    return url
}

private enum ParityError: Error, CustomStringConvertible {
    case missingResource(String)

    var description: String {
        switch self {
        case .missingResource(let name): return "Missing test resource: \(name)"
        }
    }
}
