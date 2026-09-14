/// TIFF byte order marker.
public enum ByteOrder: Sendable {
    case littleEndian  // "II"
    case bigEndian     // "MM"

    /// The two-byte ASCII marker written in the TIFF header.
    public var marker: String {
        switch self {
        case .littleEndian: "II"
        case .bigEndian:    "MM"
        }
    }

    /// Initialize from the two-byte ASCII header string.
    public init(marker: String) throws(TIFFError) {
        switch marker {
        case "II": self = .littleEndian
        case "MM": self = .bigEndian
        default:   throw .invalidByteOrder(marker)
        }
    }
}
