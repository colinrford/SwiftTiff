import Foundation

/// Deflate/zlib codec stub (Compression.deflate).
///
/// Not yet implemented — matches ObjC behavior. A future phase could add
/// zlib support via `import Compression` (Apple's framework) or a Swift zlib wrapper.
public struct DeflateCodec: CompressionCodec {
    public let rowEncoding = false

    public func decode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        throw .unsupportedCompression
    }

    public func encode(_ data: Data, byteOrder: ByteOrder) throws(TIFFError) -> Data {
        throw .unsupportedCompression
    }
}
