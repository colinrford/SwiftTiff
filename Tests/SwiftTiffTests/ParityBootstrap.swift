import Foundation
import Testing
import CryptoKit
@testable import SwiftTiff

/// Bootstrap golden JSON from Swift's own decode output (Phase 1, Q5 = 5a).
///
/// Gated by the `BOOTSTRAP_GOLDENS` environment variable so it never runs
/// in the normal test loop. Usage:
///
///     BOOTSTRAP_GOLDENS=1 swift test --filter ParityBootstrap
///
/// Writes to `Tests/SwiftTiffTests/Goldens/<fixture>.tiff.json`. These
/// files should be regenerated in Phase 2 by the ObjC reference generator;
/// any divergence between bootstrap and ObjC output is a real finding.
@Suite struct ParityBootstrap {

    @Test func generateStripped() throws {
        try bootstrap(fixture: "stripped")
    }
}

private func bootstrap(fixture: String) throws {
    guard ProcessInfo.processInfo.environment["BOOTSTRAP_GOLDENS"] == "1" else {
        // Silent skip when not explicitly enabled.
        return
    }

    let fixtureURL = try locateSourceFixture(fixture)
    let tiff = try TIFFReader.read(fromFile: fixtureURL.path)

    var images = [GoldenImage]()
    for (i, dir) in tiff.fileDirectories.enumerated() {
        let rasters = try dir.readRasters()
        images.append(
            GoldenImage(
                index: i,
                directory: buildGoldenDirectory(dir),
                rasters: buildGoldenRasters(rasters: rasters, directory: dir)
            )
        )
    }

    let golden = Golden(
        source: "\(fixture).tiff",
        generator: "SwiftTiff (bootstrap)",
        images: images
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(golden)

    let outURL = try goldenOutputURL(fixture: fixture)
    try data.write(to: outURL)
    print("Wrote bootstrap golden: \(outURL.path)")
}

// MARK: - Golden construction

private func buildGoldenDirectory(_ dir: TIFFFileDirectory) -> GoldenDirectory {
    GoldenDirectory(
        width: dir.imageWidth ?? 0,
        height: dir.imageHeight ?? 0,
        bitsPerSample: dir.bitsPerSample ?? [],
        samplesPerPixel: dir.samplesPerPixel,
        compression: Int(dir.compression?.rawValue ?? 1),
        photometricInterpretation: Int(dir.photometricInterpretation?.rawValue ?? 0),
        planarConfiguration: Int(dir.planarConfig.rawValue),
        rowsPerStrip: dir.rowsPerStrip,
        tileWidth: dir.tileWidth,
        tileHeight: dir.tileHeight,
        stripOffsets: dir.stripOffsets,
        stripByteCounts: dir.stripByteCounts,
        entries: dir.sortedEntries.map(bootstrapGoldenEntry(from:))
    )
}

private func buildGoldenRasters(
    rasters: TIFFRasters,
    directory: TIFFFileDirectory
) -> GoldenRasters {
    let samples = rasters.samplesPerPixel
    let sampleFormats = directory.sampleFormat ?? Array(repeating: 1, count: samples)

    var hashes = [String]()
    for s in 0..<samples {
        let bytes = bootstrapCanonicalSampleBytes(
            rasters: rasters,
            sample: s,
            bitsPerSample: rasters.bitsPerSample[s],
            sampleFormat: sampleFormats[s]
        )
        let digest = SHA256.hash(data: bytes)
        hashes.append(digest.map { String(format: "%02x", $0) }.joined())
    }

    let spots = buildSpotChecks(rasters: rasters, directory: directory)

    return GoldenRasters(sha256PerSample: hashes, spotChecks: spots)
}

/// Build spot-check points per Q4 (4b): corners + center + one point just
/// inside each strip (or tile) boundary beyond the first.
private func buildSpotChecks(
    rasters: TIFFRasters,
    directory: TIFFFileDirectory
) -> [SpotCheck] {
    let w = rasters.width
    let h = rasters.height
    let samples = rasters.samplesPerPixel

    var coords: [(x: Int, y: Int)] = [
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w / 2, h / 2)
    ]

    if directory.isTiled,
       let tw = directory.tileWidth, let th = directory.tileHeight,
       tw > 0, th > 0 {
        var y = th
        while y < h {
            var x = 0
            while x < w {
                coords.append((x, y))
                x += tw
            }
            y += th
        }
    } else if let rps = directory.rowsPerStrip, rps > 0 {
        var y = rps
        while y < h {
            coords.append((0, y))
            y += rps
        }
    }

    var checks = [SpotCheck]()
    for (x, y) in coords {
        for s in 0..<samples {
            checks.append(
                SpotCheck(
                    x: x,
                    y: y,
                    sample: s,
                    value: rasters.pixelSample(sample: s, x: x, y: y)
                )
            )
        }
    }
    return checks
}

// MARK: - Canonical bytes (duplicate of driver logic, kept local)

private func bootstrapCanonicalSampleBytes(
    rasters: TIFFRasters,
    sample: Int,
    bitsPerSample: Int,
    sampleFormat: Int
) -> Data {
    let w = rasters.width
    let h = rasters.height
    var data = Data()
    data.reserveCapacity(w * h * (bitsPerSample / 8))
    for y in 0..<h {
        for x in 0..<w {
            let v = rasters.pixelSample(sample: sample, x: x, y: y)
            bootstrapAppendCanonical(&data, value: v, bitsPerSample: bitsPerSample, sampleFormat: sampleFormat)
        }
    }
    return data
}

private func bootstrapAppendCanonical(
    _ data: inout Data,
    value: Double,
    bitsPerSample: Int,
    sampleFormat: Int
) {
    switch (sampleFormat, bitsPerSample) {
    case (3, 32):
        bootstrapAppendLE(&data, Float(value).bitPattern)
    case (3, 64):
        bootstrapAppendLE(&data, value.bitPattern)
    case (2, 8):
        data.append(UInt8(bitPattern: Int8(value)))
    case (2, 16):
        bootstrapAppendLE(&data, UInt16(bitPattern: Int16(value)))
    case (2, 32):
        bootstrapAppendLE(&data, UInt32(bitPattern: Int32(value)))
    case (_, 8):
        data.append(UInt8(value))
    case (_, 16):
        bootstrapAppendLE(&data, UInt16(value))
    case (_, 32):
        bootstrapAppendLE(&data, UInt32(value))
    default:
        fatalError("unsupported (sampleFormat=\(sampleFormat), bitsPerSample=\(bitsPerSample))")
    }
}

private func bootstrapAppendLE(_ data: inout Data, _ v: UInt16) {
    data.append(UInt8(v & 0xFF))
    data.append(UInt8((v >> 8) & 0xFF))
}
private func bootstrapAppendLE(_ data: inout Data, _ v: UInt32) {
    data.append(UInt8(v & 0xFF))
    data.append(UInt8((v >> 8) & 0xFF))
    data.append(UInt8((v >> 16) & 0xFF))
    data.append(UInt8((v >> 24) & 0xFF))
}
private func bootstrapAppendLE(_ data: inout Data, _ v: UInt64) {
    for i in 0..<8 { data.append(UInt8((v >> (i * 8)) & 0xFF)) }
}

// MARK: - Entry conversion

private func bootstrapGoldenEntry(from entry: FileDirectoryEntry) -> GoldenEntry {
    GoldenEntry(
        tag: Int(entry.fieldTag.rawValue),
        type: Int(entry.fieldType.rawValue),
        values: bootstrapGoldenValues(from: entry.values, fieldType: entry.fieldType)
    )
}

private func bootstrapGoldenValues(from value: EntryValue, fieldType: FieldType) -> GoldenValues {
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
    case .float, .double: return .doubles(doubles)
    case .ascii: return .strings(strings)
    default: return .ints(ints)
    }
}

// MARK: - Path resolution (source-tree, not test bundle)

/// Resolve `Tests/SwiftTiffTests/Resources/<fixture>.tiff` in the source tree.
private func locateSourceFixture(_ fixture: String) throws -> URL {
    let root = packageRoot()
    return root
        .appendingPathComponent("Tests/SwiftTiffTests/Resources")
        .appendingPathComponent("\(fixture).tiff")
}

/// Resolve the output path for a bootstrapped golden in the source tree.
private func goldenOutputURL(fixture: String) throws -> URL {
    let root = packageRoot()
    let dir = root.appendingPathComponent("Tests/SwiftTiffTests/Goldens")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("\(fixture).tiff.json")
}

/// Walks upward from `#file` to find the package root (dir containing `Package.swift`).
private func packageRoot(file: StaticString = #filePath) -> URL {
    var url = URL(fileURLWithPath: "\(file)")
    while url.pathComponents.count > 1 {
        url.deleteLastPathComponent()
        let manifest = url.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: manifest.path) {
            return url
        }
    }
    fatalError("Could not locate Package.swift above \(file)")
}
