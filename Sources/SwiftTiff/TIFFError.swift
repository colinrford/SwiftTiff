/// Errors thrown during TIFF read/write operations.
public enum TIFFError: Error, Sendable {
    case invalidByteOrder(String)
    case invalidFileIdentifier(UInt16)
    case unexpectedEndOfData(offset: Int, requested: Int, available: Int)
    case unsupportedFieldType(Int)
    case unsupportedFieldTag(Int)
    case unsupportedSampleFormat(sampleFormat: Int, bitsPerSample: Int)
    case unsupportedCompression
    case unsupportedPredictor
    case corruptedLZW
    /// The file's structure or tag values are malformed or inconsistent.
    case invalidData(String)
    /// A caller-supplied argument is invalid (window, sample indices, etc.).
    case invalidArgument(String)
    /// Valid TIFF using a feature this library does not support.
    case unsupported(String)
    case writeError(String)
}
