/// IFD entry field type per TIFF 6.0 section 2.
public enum FieldType: UInt16, Sendable {
    case byte      = 1
    case ascii     = 2
    case short     = 3
    case long      = 4
    case rational  = 5
    case sbyte     = 6
    case undefined = 7
    case sshort    = 8
    case slong     = 9
    case srational = 10
    case float     = 11
    case double    = 12

    /// Number of bytes per value of this field type.
    public var byteCount: Int {
        switch self {
        case .byte, .ascii, .sbyte, .undefined: 1
        case .short, .sshort:                   2
        case .long, .slong, .float:             4
        case .rational, .srational, .double:    8
        }
    }

    /// Number of bits per value.
    public var bitCount: Int { byteCount * 8 }

    /// Derive the field type from sample format + bits per sample.
    public static func from(
        sampleFormat: SampleFormat,
        bitsPerSample: Int
    ) throws(TIFFError) -> FieldType {
        switch (sampleFormat, bitsPerSample) {
        case (.unsignedInt, 8):  return .byte
        case (.unsignedInt, 16): return .short
        case (.unsignedInt, 32): return .long
        case (.signedInt, 8):    return .sbyte
        case (.signedInt, 16):   return .sshort
        case (.signedInt, 32):   return .slong
        case (.float, 32):       return .float
        case (.float, 64):       return .double
        default:
            throw .unsupportedSampleFormat(
                sampleFormat: Int(sampleFormat.rawValue),
                bitsPerSample: bitsPerSample
            )
        }
    }

    /// Derive the field type from a raw sample format integer + bits per sample.
    public static func from(
        sampleFormat rawValue: Int,
        bitsPerSample: Int
    ) throws(TIFFError) -> FieldType {
        guard let sf = SampleFormat(rawValue: UInt16(rawValue)) else {
            throw .unsupportedSampleFormat(
                sampleFormat: rawValue,
                bitsPerSample: bitsPerSample
            )
        }
        return try from(sampleFormat: sf, bitsPerSample: bitsPerSample)
    }

    /// Derive the sample format from this field type.
    public var sampleFormat: SampleFormat {
        get throws(TIFFError) {
            switch self {
            case .byte, .short, .long:       return .unsignedInt
            case .sbyte, .sshort, .slong:    return .signedInt
            case .float, .double:            return .float
            default:
                throw .unsupportedFieldType(Int(self.rawValue))
            }
        }
    }
}
