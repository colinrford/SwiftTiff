import Foundation

/// Top-level schema for a golden-parity JSON file.
///
/// One golden file per `.tiff` fixture. The file records what the reference
/// implementation (ObjC `tiff-ios`) produces when decoding the fixture, so
/// the Swift rewrite can be checked against it.
///
/// Phase 1 goldens are bootstrapped from the Swift implementation itself and
/// marked with `"generator": "SwiftTiff (bootstrap)"`. Phase 2 regenerates
/// them from ObjC and any divergence becomes a real finding.
struct Golden: Codable, Equatable {
    /// Filename of the source TIFF in `Tests/SwiftTiffTests/Resources/`.
    let source: String
    /// Identifier of the implementation that produced this golden.
    let generator: String
    /// One entry per Image File Directory (IFD) in the source TIFF.
    let images: [GoldenImage]
}

/// Golden data for a single IFD within a TIFF.
struct GoldenImage: Codable, Equatable {
    /// Zero-based position of this IFD in the TIFF's IFD chain.
    let index: Int
    /// Parsed IFD metadata (dimensions, tags, strip/tile layout).
    let directory: GoldenDirectory
    /// Raster verification data (hashes + spot checks). Derives from `directory`.
    let rasters: GoldenRasters
}

/// Parsed IFD metadata used for directory-level comparisons.
///
/// Common fields are pulled out for readability and diffability. The full
/// tag set lives in `entries`, sorted by tag number for stable diffs.
struct GoldenDirectory: Codable, Equatable {
    let width: Int
    let height: Int
    let bitsPerSample: [Int]
    let samplesPerPixel: Int
    /// Raw TIFF compression code (1 = none, 5 = LZW, 8 = Deflate, 32773 = PackBits).
    let compression: Int
    /// Raw TIFF photometric code (0 = WhiteIsZero, 1 = BlackIsZero, 2 = RGB, ...).
    let photometricInterpretation: Int
    /// Raw TIFF planar config (1 = chunky, 2 = planar).
    let planarConfiguration: Int
    /// Present for stripped images, nil for tiled.
    let rowsPerStrip: Int?
    /// Present for tiled images, nil for stripped.
    let tileWidth: Int?
    /// Present for tiled images, nil for stripped.
    let tileHeight: Int?
    /// File offsets of each strip (stripped) or tile (tiled).
    let stripOffsets: [Int]?
    /// Byte counts for each strip/tile.
    let stripByteCounts: [Int]?
    /// Full IFD entry list, sorted by tag number.
    let entries: [GoldenEntry]
}

/// A single IFD entry: tag + type + values.
struct GoldenEntry: Codable, Equatable {
    /// Raw TIFF tag number (e.g. 256 for ImageWidth).
    let tag: Int
    /// Raw TIFF field type code (1=BYTE, 2=ASCII, 3=SHORT, 4=LONG, ...).
    let type: Int
    /// The entry's value(s). Representation depends on type.
    let values: GoldenValues
}

/// Union of possible entry value representations.
///
/// TIFF entries can hold integers (BYTE/SHORT/LONG/SBYTE/SSHORT/SLONG),
/// floating-point numbers (FLOAT/DOUBLE/RATIONAL/SRATIONAL), or ASCII strings.
/// Rationals are flattened to `[numerator, denominator, ...]` pairs for
/// simplicity; the reader's typed structure can be validated separately.
enum GoldenValues: Equatable {
    case ints([Int])
    case doubles([Double])
    case strings([String])
}

extension GoldenValues: Codable {
    private enum CodingKeys: String, CodingKey {
        case ints, doubles, strings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try container.decodeIfPresent([Int].self, forKey: .ints) {
            self = .ints(v)
        } else if let v = try container.decodeIfPresent([Double].self, forKey: .doubles) {
            self = .doubles(v)
        } else if let v = try container.decodeIfPresent([String].self, forKey: .strings) {
            self = .strings(v)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .ints,
                in: container,
                debugDescription: "GoldenValues must contain one of: ints, doubles, strings"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ints(let v): try container.encode(v, forKey: .ints)
        case .doubles(let v): try container.encode(v, forKey: .doubles)
        case .strings(let v): try container.encode(v, forKey: .strings)
        }
    }
}

/// Raster verification data.
///
/// Full raster dumps would be huge (MBs of JSON). Instead we record:
/// - A SHA-256 per sample plane, computed over the canonical little-endian
///   byte representation of that plane at its declared bit depth. This gives
///   byte-exact equivalence checks.
/// - A small set of `SpotCheck`s at deterministic coordinates (corners,
///   center, strip/tile boundaries). When a hash mismatches, spot checks
///   produce readable errors pointing at specific pixels.
///
/// Dimensions and bit depth are NOT duplicated here — they live in the
/// companion `GoldenDirectory`. The driver validates consistency implicitly
/// by indexing `sha256PerSample[0..<samplesPerPixel]`.
struct GoldenRasters: Codable, Equatable {
    /// Lowercase hex SHA-256 digests, one per sample plane.
    let sha256PerSample: [String]
    /// Per-pixel value assertions at specific coordinates.
    let spotChecks: [SpotCheck]
}

/// A single `(x, y, sample) → value` assertion.
///
/// `value` is `Double` so the same struct can represent uint8/uint16/uint32/
/// int32/float32/float64 sample values without loss for the bit depths we
/// support. Integer comparisons use exact equality; floating-point comparisons
/// use exact equality as well (the pipeline is deterministic — there's no
/// numerical error to tolerate).
struct SpotCheck: Codable, Equatable {
    let x: Int
    let y: Int
    let sample: Int
    let value: Double
}
